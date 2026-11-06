import Foundation

@main
@MainActor
struct ProcessTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        measuresCPU()
        keepsRowsInPlace()
        readsPaths()
        readsNetstat()
        filters()
        followsRows()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func sample(_ pid: Int32, cpu: UInt64, memory: Int64 = 1, path: String = "/bin/zsh", started: UInt64 = 1)
        -> ProcessSample
    {
        ProcessSample(
            identity: ProcessIdentity(pid: pid, startedAt: started), path: path, cpuNanoseconds: cpu,
            memoryBytes: memory)
    }

    static func process(_ pid: Int32, cpu: Double, memory: Int64 = 1) -> RunningProcess {
        RunningProcess(
            identity: ProcessIdentity(pid: pid, startedAt: 1), path: "/bin/p\(pid)", cpu: cpu,
            memoryBytes: memory)
    }

    static func measuresCPU() {
        let before = ProcessReading(
            samples: [sample(1, cpu: 1_000), sample(2, cpu: 5_000), sample(3, cpu: 0, started: 7)],
            takenAtNanoseconds: 10_000)
        let after = ProcessReading(
            samples: [
                sample(1, cpu: 6_000), sample(2, cpu: 25_000), sample(3, cpu: 9_000, started: 8),
                sample(4, cpu: 3_000)
            ],
            takenAtNanoseconds: 20_000)
        let cpu = Dictionary(uniqueKeysWithValues: RunningProcess.measure(after, since: before).map { ($0.pid, $0.cpu) })
        expect(cpu[1] == 50, "half a core over the window — got \(cpu[1] ?? -1)")
        expect(cpu[2] == 200, "two cores' worth on a multithreaded process")
        expect(cpu[3] == 0, "a reused pid is a new process, with nothing to compare")
        expect(cpu[4] == 0, "a process born inside the window has no share yet")
        expect(
            RunningProcess.measure(after, since: nil).allSatisfy { $0.cpu == 0 }, "one reading measures nothing")
    }

    static func keepsRowsInPlace() {
        let shown = [process(1, cpu: 9), process(2, cpu: 5), process(3, cpu: 1)]
        let fresh = [process(3, cpu: 50), process(1, cpu: 0), process(4, cpu: 2), process(5, cpu: 7)]
        let arranged = RunningProcess.arranged(fresh, keepingOrderOf: shown)
        expect(arranged.map(\.pid) == [1, 3, 5, 4], "shown rows keep their order; new ones follow, busiest first")
        expect(arranged.first { $0.pid == 3 }?.cpu == 50, "kept rows carry the fresh numbers")
        expect(
            RunningProcess.arranged(fresh, keepingOrderOf: []).map(\.pid) == [3, 5, 4, 1],
            "nothing shown yet sorts the lot")
        expect(
            RunningProcess.ordered([process(1, cpu: 0, memory: 5), process(2, cpu: 0, memory: 9)]).map(\.pid)
                == [2, 1], "a tie goes to the larger process")
    }

    static func readsPaths() {
        let helper = "/Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper"
        expect(ProcessPath.name(helper) == "Claude Helper", "the name is the executable")
        expect(ProcessPath.bundle(helper) == "/Applications/Claude.app", "a helper wears its outermost app")
        expect(ProcessPath.bundle("/usr/sbin/distnoted") == nil, "a daemon has no bundle")
        expect(ProcessPath.bundle("Contents/MacOS/x.app/y") == nil, "a relative path is no bundle")
        expect(ProcessPath.name("node") == "node", "a bare command is its own name")
    }

    // Trimmed after the process column; real lines carry eight more fields.
    static let netstatOutput = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address    Foreign Address    (state)  rxbytes txbytes rhiwat shiwat   process:pid  state
        tcp4  0 0  192.168.1.2.64640  35.228.118.177.443  ESTABLISHED  9260 2033 131072 132352  pmd:29490  00082
        tcp4  0 0  127.0.0.1.3000     *.*  LISTEN  0 0 131072 131072              node:5267  00100
        tcp6  0 0  *.3000             *.*  LISTEN  0 0 131072 131072              node:5267  00100
        tcp4  0 0  127.0.0.1.49796    *.*  LISTEN  0 0 131072 131072  Code Helper (Plu:39354  00100
        tcp4  0 0  127.0.0.1.53       *.*  LISTEN  0 0 131072 131072     dnscryptproxy:31243  00080
        tcp6  0 0  ::1.5000           *.*  LISTEN  0 0 131072 131072     DriverApp.Api:56332  00100
        tcp4  0 0  127.0.0.1.5000     *.*  LISTEN  0 0 131072 131072     DriverApp.Api:56332  00100
        tcp4  0 0  *.8000             *.*  LISTEN  0 0 131072 131072             python3:0  00100
        garbage line
        """

    static func readsNetstat() {
        let ports = ListeningPort.parse(netstatOutput: netstatOutput)
        expect(ports.map(\.port) == [53, 3000, 5000, 49796], "listeners only, sorted, IPv4 and IPv6 merged")
        expect(ports.first { $0.port == 3000 }?.address == "*", "a wildcard socket wins the merged row")
        expect(ports.first { $0.port == 5000 }?.address == "::1", "else the first address stays")
        expect(ports.first { $0.port == 49796 }?.command == "Code Helper (Plu", "a name with spaces stays whole")
        expect(ports.first { $0.port == 49796 }?.pid == 39354, "the pid follows the name's last colon")
        expect(ports.first { $0.port == 53 }?.holder == .unknown, "the holder waits for the kernel")
        var named = ports[0]
        named.path = "/opt/bin/dnscryptproxy-long-name"
        expect(named.name == "dnscryptproxy-long-name", "the executable's path outranks netstat's cut name")
        named.holder = .reader(ProcessIdentity(pid: 31243, startedAt: 4))
        expect(named.identity?.startedAt == 4, "only the reader's listener carries an identity to signal")
    }

    static func filters() {
        let processes = [
            RunningProcess(
                identity: ProcessIdentity(pid: 5267, startedAt: 1), path: "/opt/claude/claude", cpu: 1,
                memoryBytes: 1),
            RunningProcess(
                identity: ProcessIdentity(pid: 5392, startedAt: 1),
                path: "/Applications/Claude.app/Contents/MacOS/Claude Helper", cpu: 1, memoryBytes: 1),
            RunningProcess(
                identity: ProcessIdentity(pid: 697, startedAt: 1), path: "/usr/sbin/distnoted", cpu: 1,
                memoryBytes: 1),
            RunningProcess(
                identity: ProcessIdentity(pid: 900, startedAt: 1), path: "/usr/bin/python3", cpu: 1,
                memoryBytes: 1)
        ]
        let ports = ListeningPort.parse(
            netstatOutput: """
                tcp4 0 0 127.0.0.1.3000 *.* LISTEN 0 0 1 1 claude:5267 00100
                tcp4 0 0 *.8000 *.* LISTEN 0 0 1 1 python3:900 00100
                """)
        let byPID = ProcessQuery.portsByProcess(ports)
        func pids(_ query: String) -> [Int32] {
            ProcessQuery.filter(processes, ports: byPID, query: query).map(\.pid)
        }
        expect(pids("").count == 4, "empty keeps all")
        expect(pids("CLAUDE") == [5267, 5392], "names ignore case")
        expect(pids("3000") == [5267], "a port finds its process")
        expect(pids(":8000") == [900], "a colon-prefixed port")
        expect(pids("697") == [697], "a pid")
        expect(ProcessQuery.filter(ports, query: "30").map(\.port) == [3000], "a port prefix")
        expect(ProcessQuery.filter(ports, query: "python").map(\.port) == [8000], "a command")
    }

    static func followsRows() {
        let old = ["a", "b", "c", "d"]
        expect(RowFollowing.selection(1, from: old, to: ["c", "a", "b"]) == 2, "the highlight stays on its row")
        expect(RowFollowing.selection(1, from: old, to: ["a", "c", "d"]) == 1, "a quit row hands over to the next")
        expect(RowFollowing.selection(3, from: old, to: ["a", "b", "c"]) == 2, "quitting the last steps back one")
        expect(RowFollowing.selection(0, from: old, to: []) == 0, "an empty list rests at the top")
        expect(RowFollowing.selection(4, from: [], to: ["x", "y"]) == 0, "a fresh sweep lands at the top")
    }
}

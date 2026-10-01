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
        readsPS()
        readsLsof()
        filters()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static let psOutput = """
          697   0.0   5936 /usr/sbin/distnoted
         5267  12.5 131904 /Users/me/Library/Application Support/Claude/claude.app/Contents/MacOS/claude
         5392   0.0  52560 /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper
          900   3.0   1000 node
        garbage line
          901   x   1000 /bin/zsh
        """

    static let lsofOutput = """
        p5267
        cnode
        f17
        n127.0.0.1:3000
        f18
        n[::1]:3000
        p15690
        crapportd
        f10
        n*:52592
        p900
        cpython3
        f4
        n*:8000
        """

    static func readsPS() {
        let processes = RunningProcess.parse(psOutput: psOutput)
        expect(processes.count == 4, "four good lines, the rest skipped — got \(processes.count)")
        let claude = processes.first { $0.pid == 5267 }
        expect(claude?.cpu == 12.5, "cpu")
        expect(claude?.memoryBytes == 131904 * 1024, "rss is in KiB")
        expect(claude?.path.hasSuffix("MacOS/claude") == true, "a path with spaces stays whole")
        expect(claude?.name == "claude", "the name is the executable")
        expect(
            processes.first { $0.pid == 5392 }?.bundlePath == "/Applications/Claude.app",
            "a helper's bundle is the app it ships inside")
        expect(processes.first { $0.pid == 697 }?.bundlePath == nil, "a daemon has no bundle")
        expect(processes.first { $0.pid == 900 }?.name == "node", "a bare command is its own name")
        expect(RunningProcess.ordered(processes).map(\.pid) == [5267, 900, 5392, 697],
               "busiest first, then largest")
    }

    static func readsLsof() {
        let ports = ListeningPort.parse(lsofOutput: lsofOutput)
        expect(ports.map(\.port) == [3000, 8000, 52592], "sorted by port, IPv4 and IPv6 merged")
        expect(ports.first?.command == "node" && ports.first?.address == "127.0.0.1", "first wins")
        expect(ports.last?.address == "*", "every interface")
        expect(ports.last?.pid == 15690, "each socket belongs to the process above it")
    }

    static func filters() {
        let processes = RunningProcess.parse(psOutput: psOutput)
        let ports = ListeningPort.parse(lsofOutput: lsofOutput)
        let byPID = ProcessQuery.portsByProcess(ports)
        func pids(_ query: String) -> [Int32] {
            ProcessQuery.filter(processes, ports: byPID, query: query).map(\.pid)
        }
        expect(pids("").count == 4, "empty keeps all")
        expect(pids("CLAUDE") == [5267, 5392], "names ignore case")
        expect(pids("3000") == [5267], "a port finds its process")
        expect(pids(":8000") == [900], "a colon-prefixed port")
        expect(pids("697") == [697], "a pid")
        expect(
            ProcessQuery.filter(ports, query: "30").map(\.port) == [3000], "a port prefix")
        expect(ProcessQuery.filter(ports, query: "python").map(\.port) == [8000], "a command")
    }
}

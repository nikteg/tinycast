#!/usr/bin/env node
// Generate Typing Practice's word list and quotes from Monkeytype's English data.
//
// Usage: node Scripts/gen-typing-data.js [english.json quotes-english.json]
// Downloads the sources when paths aren't given. Run occasionally, commit the output.
//
//   Tinycast/Features/TypingPractice/Resources/TypingWords.generated.json  — ["the", "be", …]
//   Tinycast/Features/TypingPractice/Resources/TypingQuotes.generated.json — [{id, text, source}, …]
//
// Raycast built its Typing Practice with Monkeytype, and these are the lists Monkeytype's own
// "english" language and English quotes serve. Both are GPL-3.0, which the AGPL may carry; the
// attribution lives in NOTICE.md. The commit is pinned so a re-run is reproducible; bump it on purpose.

const fs = require("fs");
const path = require("path");

const COMMIT = "4bd46c6ca1c2b02ba0203b83b6f0b32a2a5a53ec";
const BASE = `https://raw.githubusercontent.com/monkeytypegame/monkeytype/${COMMIT}/frontend/static`;
const OUT = path.join(__dirname, "..", "Tinycast", "Features", "TypingPractice", "Resources");

async function load(url, argPath) {
  if (argPath) return JSON.parse(fs.readFileSync(argPath, "utf8"));
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.json();
}

// Monkeytype types straight quotes and plain dashes; a curly one would be untypeable on most layouts.
function typeable(text) {
  return text
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, "-")
    .replace(/…/g, "...")
    .replace(/\s+/g, " ")
    .trim();
}

async function main() {
  const [wordsPath, quotesPath] = process.argv.slice(2);
  const language = await load(`${BASE}/languages/english.json`, wordsPath);
  const quotes = await load(`${BASE}/quotes/english.json`, quotesPath);

  const words = [...new Set(language.words.map((word) => word.trim()).filter(Boolean))];
  const seen = new Set();
  const rows = [];
  for (const quote of quotes.quotes) {
    const text = typeable(quote.text);
    // Anything left outside printable ASCII has no key to press on a US layout.
    if (!text || seen.has(text) || /[^\x20-\x7E]/.test(text)) continue;
    seen.add(text);
    rows.push({ id: quote.id, text, source: typeable(quote.source ?? "") });
  }
  rows.sort((a, b) => a.id - b.id);

  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, "TypingWords.generated.json"), JSON.stringify(words) + "\n");
  fs.writeFileSync(path.join(OUT, "TypingQuotes.generated.json"), JSON.stringify(rows) + "\n");
  console.log(`${words.length} words, ${rows.length} quotes (${quotes.quotes.length - rows.length} dropped)`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

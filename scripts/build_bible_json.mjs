#!/usr/bin/env node
// Converts a public-domain Bible CSV into the JSON the app reads offline.
//
// Input: a CSV in the scrollmapper "bible_databases" layout (columns id,b,c,v,t),
// e.g. t_kjv.csv for the King James Version or a Louis Segond 1910 export.
// Output: <CODE>.json  {"code","name","books":[{"n","name","chapters":[[verse, ...], ...]}]}
//
// Usage:
//   node scripts/build_bible_json.mjs --in t_kjv.csv --code KJV --name "King James Version" --lang en
//   node scripts/build_bible_json.mjs --in lsg1910.csv --code LSG1910 --name "Louis Segond 1910" --lang fr
// Then upload the file to the public "bible" storage bucket:
//   supabase storage cp KJV.json ss:///bible/KJV.json
import { readFileSync, writeFileSync } from "node:fs";

const NAMES = {
  fr: [
    "Genèse", "Exode", "Lévitique", "Nombres", "Deutéronome", "Josué", "Juges", "Ruth",
    "1 Samuel", "2 Samuel", "1 Rois", "2 Rois", "1 Chroniques", "2 Chroniques", "Esdras",
    "Néhémie", "Esther", "Job", "Psaumes", "Proverbes", "Ecclésiaste", "Cantique des cantiques",
    "Ésaïe", "Jérémie", "Lamentations", "Ézéchiel", "Daniel", "Osée", "Joël", "Amos", "Abdias",
    "Jonas", "Michée", "Nahum", "Habacuc", "Sophonie", "Aggée", "Zacharie", "Malachie",
    "Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "1 Corinthiens", "2 Corinthiens",
    "Galates", "Éphésiens", "Philippiens", "Colossiens", "1 Thessaloniciens", "2 Thessaloniciens",
    "1 Timothée", "2 Timothée", "Tite", "Philémon", "Hébreux", "Jacques", "1 Pierre", "2 Pierre",
    "1 Jean", "2 Jean", "3 Jean", "Jude", "Apocalypse",
  ],
  en: [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
    "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
    "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
    "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah",
    "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
    "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
    "1 John", "2 John", "3 John", "Jude", "Revelation",
  ],
};

function args() {
  const a = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) a[argv[i].replace(/^--/, "")] = argv[i + 1];
  for (const k of ["in", "code", "name", "lang"]) {
    if (!a[k]) {
      console.error(`missing --${k}`);
      process.exit(1);
    }
  }
  if (!NAMES[a.lang]) throw new Error("--lang must be fr or en");
  return a;
}

// Minimal RFC 4180 CSV parser (quoted fields, doubled quotes, commas/newlines in quotes).
function* parseCsv(text) {
  let row = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") { row.push(field); field = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(field); field = "";
      if (row.length > 1 || row[0] !== "") yield row;
      row = [];
    } else field += ch;
  }
  if (field !== "" || row.length) { row.push(field); yield row; }
}

const { in: input, code, name, lang, out = `${code}.json` } = args();
const rows = parseCsv(readFileSync(input, "utf8").replace(/^﻿/, ""));
const header = rows.next().value.map((h) => h.trim().toLowerCase());
const col = (n) => {
  const i = header.indexOf(n);
  if (i < 0) throw new Error(`CSV needs a "${n}" column (found: ${header.join(", ")})`);
  return i;
};
const [ib, ic, iv, it] = ["b", "c", "v", "t"].map(col);

const books = new Map();
let count = 0;
for (const r of rows) {
  const b = Number(r[ib]), c = Number(r[ic]), v = Number(r[iv]);
  if (!(b >= 1 && b <= 66 && c >= 1 && v >= 1)) continue;
  if (!books.has(b)) books.set(b, []);
  const chapters = books.get(b);
  while (chapters.length < c) chapters.push([]);
  const verses = chapters[c - 1];
  while (verses.length < v - 1) verses.push(""); // keep verse numbers aligned
  verses[v - 1] = r[it].trim();
  count++;
}

const result = {
  code,
  name,
  books: [...books.keys()].sort((a, b) => a - b).map((n) => ({
    n,
    name: NAMES[lang][n - 1],
    chapters: books.get(n),
  })),
};
writeFileSync(out, JSON.stringify(result));
console.log(`${out}: ${result.books.length} books, ${count} verses`);

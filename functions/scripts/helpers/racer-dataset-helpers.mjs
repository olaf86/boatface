import path from "node:path";

export const OFFICIAL_DOWNLOAD_PAGE_URL =
  "https://www.boatrace.jp/owpc/pc/extra/data/download.html";
export const OFFICIAL_PROFILE_URL_BASE =
  "https://www.boatrace.jp/owpc/pc/data/racersearch/profile";
export const OFFICIAL_RACER_PHOTO_URL_BASE =
  "https://www.boatrace.jp/racerphoto/";

const rosterPrefixFieldLayout = [
  {key: "registrationNumber", width: 4, type: "int"},
  {key: "name", width: 16, type: "string"},
  {key: "nameKana", width: 15, type: "string"},
  {key: "branch", width: 4, type: "string"},
  {key: "class", width: 2, type: "string"},
  {key: "birthEra", width: 1, type: "string"},
  {key: "birthDateShort", width: 6, type: "string"},
  {key: "genderCode", width: 1, type: "string"},
  {key: "age", width: 2, type: "int"},
  {key: "heightCm", width: 3, type: "int"},
  {key: "weightKg", width: 2, type: "int"},
  {key: "bloodType", width: 2, type: "string"},
  {key: "winRate", width: 4, type: "scaled", scale: 2},
  {key: "placeRate", width: 4, type: "scaled", scale: 1},
  {key: "firstPlaceCount", width: 3, type: "int"},
  {key: "secondPlaceCount", width: 3, type: "int"},
  {key: "raceCount", width: 3, type: "int"},
  {key: "finalsCount", width: 2, type: "int"},
  {key: "winsCount", width: 2, type: "int"},
  {key: "averageStartTiming", width: 3, type: "scaled", scale: 2},
];

const rosterTrainingTermOffset = 195;
const rosterTrainingTermWidth = 3;
const rosterHometownOffset = 410;
const rosterHometownWidth = 6;

const shiftJisDecoder = new TextDecoder("shift_jis");

function datasetIdToTermLabel(datasetId) {
  const match = /^(\d{4})-H([12])$/.exec(datasetId);
  if (!match) {
    throw new Error(`Invalid datasetId: ${datasetId}`);
  }

  return `${match[1]}年 ${match[2] === "1" ? "前期" : "後期"}`;
}

function stripHtml(value) {
  return value
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();
}

export function extractDatasetArchiveUrl(downloadPageHtml, datasetId) {
  const termLabel = datasetIdToTermLabel(datasetId);
  const listItemPattern = /<li\b[^>]*>([\s\S]*?)<\/li>/gi;
  let itemMatch;
  while ((itemMatch = listItemPattern.exec(downloadPageHtml)) !== null) {
    const itemHtml = itemMatch[1];
    const itemText = stripHtml(itemHtml);
    if (!itemText.includes(termLabel)) {
      continue;
    }

    const anchorPattern = /<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
    let anchorMatch;
    while ((anchorMatch = anchorPattern.exec(itemHtml)) !== null) {
      const anchorText = stripHtml(anchorMatch[2]);
      if (!termLabel.endsWith(anchorText)) {
        continue;
      }

      return new URL(anchorMatch[1], OFFICIAL_DOWNLOAD_PAGE_URL).toString();
    }
  }

  throw new Error(`Could not find a download link for ${termLabel}`);
}

function decodeField(buffer) {
  return shiftJisDecoder.decode(buffer).trim();
}

function convertField(type, value) {
  if (!value) {
    return null;
  }

  if (type === "string") {
    return value;
  }

  if (type === "int") {
    const normalized = Number.parseInt(value, 10);
    return Number.isNaN(normalized) ? null : normalized;
  }

  if (type === "float") {
    const normalized = Number.parseFloat(value);
    return Number.isNaN(normalized) ? null : normalized;
  }

  if (type === "scaled") {
    return value;
  }

  if (type === "date") {
    return /^\d{4}\/\d{2}\/\d{2}$/.test(value) ? value.replaceAll("/", "-") : value;
  }

  return value;
}

function convertScaledDecimal(value, scale) {
  if (!value) {
    return null;
  }

  const normalized = Number.parseInt(value, 10);
  if (Number.isNaN(normalized)) {
    return null;
  }

  return normalized / (10 ** scale);
}

function expandBirthDate(birthEra, birthDateShort) {
  if (!birthEra || !/^\d{6}$/.test(birthDateShort)) {
    return null;
  }

  const yearPart = Number.parseInt(birthDateShort.slice(0, 2), 10);
  const month = birthDateShort.slice(2, 4);
  const day = birthDateShort.slice(4, 6);
  if (Number.isNaN(yearPart)) {
    return null;
  }

  const eraStartYear = {
    M: 1867,
    T: 1911,
    S: 1925,
    H: 1988,
    R: 2018,
  }[birthEra];
  if (!eraStartYear) {
    return null;
  }

  return `${eraStartYear + yearPart}-${month}-${day}`;
}

function normalizeGender(genderCode) {
  if (genderCode === "1") {
    return "male";
  }
  if (genderCode === "2") {
    return "female";
  }
  return null;
}

function normalizeHometown(value) {
  if (!value) {
    return null;
  }

  const normalized = value.replaceAll("　", "").trim();
  return normalized || null;
}

function normalizeName(value) {
  if (!value) {
    return null;
  }

  const normalized = value.trim();
  const chunks = normalized
    .split(/　{2,}/)
    .map((chunk) => chunk.replaceAll("　", "").trim())
    .filter(Boolean);

  if (chunks.length >= 2) {
    return `${chunks[0]} ${chunks.slice(1).join("")}`;
  }

  return normalized.replaceAll("　", "");
}

function normalizeNameKana(value) {
  if (!value) {
    return null;
  }

  return value
    .normalize("NFKC")
    .replace(/\s+/g, " ")
    .trim();
}

export function parseRosterFileBuffer(buffer, datasetId) {
  const racers = [];
  for (const rawLine of buffer.toString("binary").split("\n")) {
    const lineBuffer = Buffer.from(rawLine.replace(/\r$/, ""), "binary");
    if (lineBuffer.length === 0) {
      continue;
    }

    let offset = 0;
    const racer = {
      id: "",
      datasetId,
      isActive: true,
      sourceType: "boatrace-term-download",
      profileUrl: "",
    };

    for (const field of rosterPrefixFieldLayout) {
      const value = decodeField(lineBuffer.subarray(offset, offset + field.width));
      racer[field.key] =
        field.type === "scaled" ? convertScaledDecimal(value, field.scale) : convertField(field.type, value);
      offset += field.width;
    }

    if (!racer.registrationNumber || !racer.name) {
      continue;
    }

    racer.name = normalizeName(racer.name);
    racer.nameKana = normalizeNameKana(racer.nameKana);

    racer.birthDate = expandBirthDate(racer.birthEra, racer.birthDateShort);
    racer.gender = normalizeGender(racer.genderCode);
    racer.term = convertField(
      "int",
      decodeField(
        lineBuffer.subarray(
          rosterTrainingTermOffset,
          rosterTrainingTermOffset + rosterTrainingTermWidth,
        ),
      ),
    );
    racer.hometown = normalizeHometown(
      decodeField(
        lineBuffer.subarray(rosterHometownOffset, rosterHometownOffset + rosterHometownWidth),
      ),
    );
    delete racer.birthEra;
    delete racer.birthDateShort;
    delete racer.genderCode;

    racer.id = `racer-${racer.registrationNumber}`;
    racer.profileUrl =
      `${OFFICIAL_PROFILE_URL_BASE}?toban=${String(racer.registrationNumber).padStart(4, "0")}`;
    racer.imageUrl = `${OFFICIAL_RACER_PHOTO_URL_BASE}${String(racer.registrationNumber).padStart(4, "0")}.jpg`;
    racer.imageSource = "boatrace-photo";
    racers.push(racer);
  }

  return racers;
}

function extractFirstMatch(html, pattern) {
  const match = pattern.exec(html);
  return match ? stripHtml(match[1]) : null;
}

export function extractLabeledTableValue(html, label) {
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return extractFirstMatch(
    html,
    new RegExp(`<th[^>]*>\\s*${escapedLabel}\\s*<\\/th>\\s*<td[^>]*>([\\s\\S]*?)<\\/td>`, "i"),
  );
}

export function extractProfileImageUrl(html) {
  const scopedPatterns = [
    /<div[^>]*class="[^"]*racer.*?(?:photo|image)[^"]*"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/i,
    /<img[^>]+src="([^"]+)"[^>]+class="[^"]*racer.*?(?:photo|image)[^"]*"/i,
    /<img[^>]+src="([^"]+)"[^>]+alt="[^"]*(?:選手|レーサー)[^"]*"/i,
  ];

  for (const pattern of scopedPatterns) {
    const match = pattern.exec(html);
    if (match) {
      return new URL(match[1], OFFICIAL_PROFILE_URL_BASE).toString();
    }
  }

  return null;
}

export function mergeProfileDetails(racer, profileHtml) {
  const merged = {...racer};
  const maybeClass = extractLabeledTableValue(profileHtml, "級別");
  const maybeBranch = extractLabeledTableValue(profileHtml, "支部");
  const maybeHometown = extractLabeledTableValue(profileHtml, "出身地");
  const maybeBirthDate = extractLabeledTableValue(profileHtml, "生年月日");
  const maybeHeight = extractLabeledTableValue(profileHtml, "身長");
  const maybeWeight = extractLabeledTableValue(profileHtml, "体重");
  const maybeBloodType = extractLabeledTableValue(profileHtml, "血液型");
  const maybeTerm = extractLabeledTableValue(profileHtml, "登録期");
  const maybeImageUrl = extractProfileImageUrl(profileHtml);

  if (maybeClass) {
    merged.class = maybeClass;
  }
  if (maybeBranch) {
    merged.branch = maybeBranch;
  }
  if (maybeHometown) {
    merged.hometown = maybeHometown;
  }
  if (maybeBirthDate) {
    merged.birthDate = maybeBirthDate.replaceAll("/", "-");
  }
  if (maybeHeight) {
    const normalized = Number.parseInt(maybeHeight.replace(/[^\d]/g, ""), 10);
    if (!Number.isNaN(normalized)) {
      merged.heightCm = normalized;
    }
  }
  if (maybeWeight) {
    const normalized = Number.parseFloat(maybeWeight.replace(/[^\d.]/g, ""));
    if (!Number.isNaN(normalized)) {
      merged.weightKg = normalized;
    }
  }
  if (maybeBloodType) {
    merged.bloodType = maybeBloodType;
  }
  if (maybeTerm) {
    const normalized = Number.parseInt(maybeTerm.replace(/[^\d]/g, ""), 10);
    if (!Number.isNaN(normalized)) {
      merged.term = normalized;
    }
  }
  if (maybeImageUrl) {
    merged.imageUrl = maybeImageUrl;
    merged.imageSource = "boatrace-profile";
  }

  return merged;
}

export function buildImageStoragePath(datasetId, registrationNumber, imageUrl) {
  const extension = path.extname(new URL(imageUrl).pathname) || ".jpg";
  return `racer-images/${datasetId}/${registrationNumber}${extension}`;
}

export function buildImagePackStoragePath(datasetId) {
  return `racer-image-packs/${datasetId}.zip`;
}

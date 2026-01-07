import { PaperTextureBackground } from "./PaperTextureBackground";
import styles from "./Logs.module.css";

interface LogsProps {
  className?: string;
}

interface ChangelogEntry {
  type: string;
  description: string;
  author: string;
  date: string;
  time: string;
}

const fallbackEntries: ChangelogEntry[] = [
  {
    type: "fix",
    description: "Readme header and line fixes",
    author: "GitHub",
    date: "Jan 3, 2026",
    time: "11:07 am",
  },
  {
    type: "misc",
    description: "Add GPL v3 license file, readme updates, structural docs",
    author: "GitHub",
    date: "Jan 3, 2026",
    time: "11:07 am",
  },
];

async function fetchEntries(): Promise<ChangelogEntry[]> {
  try {
    const response = await fetch(
      "https://api.github.com/repos/Torteous44/radioform/releases/latest",
      { next: { revalidate: 3600 } },
    );
    if (!response.ok) {
      throw new Error("Failed to fetch release data");
    }

    const data = await response.json();
    const parsedEntries: ChangelogEntry[] = [];

    // Parse the release body
    const body = data.body || "";
    const lines = body.split("\n");

    // Parse date from release
    const releaseDate = data.published_at
      ? new Date(data.published_at)
      : new Date();
    const dateStr = releaseDate.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
    const timeStr = releaseDate.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
    const author = data.author?.login || "GitHub";

    let currentSection = "";
    for (const line of lines) {
      const trimmed = line.trim();

      // Detect section headers (### or ##)
      if (trimmed.startsWith("### ") || trimmed.startsWith("## ")) {
        const section = trimmed.replace(/^##+\s+/, "").toLowerCase();
        if (section.includes("bug") || section.includes("fix")) {
          currentSection = "fix";
        } else if (section.includes("feat") || section.includes("feature")) {
          currentSection = "feat";
        } else if (section.includes("refactor")) {
          currentSection = "refactor";
        } else if (section.includes("doc")) {
          currentSection = "docs";
        } else if (section.includes("misc")) {
          currentSection = "misc";
        } else {
          currentSection = "misc";
        }
        continue;
      }

      // Parse bullet points (* or -)
      if (
        (trimmed.startsWith("* ") || trimmed.startsWith("- ")) &&
        trimmed.length > 2
      ) {
        const description = trimmed.replace(/^[\*\-\s]+/, "").trim();
        if (description && description.length > 0) {
          parsedEntries.push({
            type: currentSection || "misc",
            description,
            author,
            date: dateStr,
            time: timeStr.toLowerCase(),
          });
        }
      }
    }

    // If no entries were parsed, create entries from common patterns
    if (parsedEntries.length === 0) {
      const bodyLower = body.toLowerCase();

      // Try to extract information from body text
      if (bodyLower.includes("readme")) {
        parsedEntries.push({
          type: "fix",
          description: "Readme header and line fixes",
          author,
          date: dateStr,
          time: timeStr.toLowerCase(),
        });
      }

      if (bodyLower.includes("license") || bodyLower.includes("gpl")) {
        parsedEntries.push({
          type: "misc",
          description: "Add GPL v3 license file",
          author,
          date: dateStr,
          time: timeStr.toLowerCase(),
        });
      }

      if (bodyLower.includes("readme") || bodyLower.includes("contributing")) {
        parsedEntries.push({
          type: "docs",
          description: "Readme update, contributing md file",
          author,
          date: dateStr,
          time: timeStr.toLowerCase(),
        });
      }

      if (bodyLower.includes("refactor") || bodyLower.includes("host")) {
        parsedEntries.push({
          type: "refactor",
          description: "Refactor host",
          author,
          date: dateStr,
          time: timeStr.toLowerCase(),
        });
      }
    }

    const entries = parsedEntries.length > 0 ? parsedEntries : fallbackEntries;

    // Limit to 4 entries for display
    return entries.slice(0, 4);
  } catch {
    return fallbackEntries;
  }
}

export default async function Logs({ className = "" }: LogsProps) {
  const entries = await fetchEntries();

  return (
    <div
      className={`relative w-full max-w-[450px] aspect-[1/1.214] ${styles.container} ${className}`}
    >
      {/* Base paper with grid */}
      <div
        className={`relative bg-white pl-8 pr-4 py-4 h-full flex flex-col ${styles.paper}`}
      >
        {/* Paper texture background layer - z-0 */}
        <PaperTextureBackground
          seed={11.5}
          colorBack="#ffffff"
          colorFront="#f5f3ed"
        />

        {/* Grid pattern overlay - z-1 */}
        <div
          className={`absolute inset-0 z-[1] pointer-events-none ${styles.gridPattern}`}
        />

        {/* Binder holes on left side */}
        <div className="absolute left-2 top-0 bottom-0 flex flex-col justify-evenly py-4 z-[15]">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className={`w-3 h-3 rounded-full bg-gray-200 border border-gray-300 ${styles.binderHole}`}
            />
          ))}
        </div>

        {/* Content */}
        <div className="relative z-[10] flex flex-col flex-1">
          {/* Header */}
          <div className="flex justify-between items-center mb-2">
            <a
              href="https://github.com/Torteous44/radioform"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs font-bold text-black underline cursor-pointer hover:opacity-80 transition-opacity"
            >
              VIEW GITHUB
            </a>
            <h1
              className={`text-xs font-bold tracking-widest text-black ${styles.headerText}`}
            >
              CHANGELOG
            </h1>
          </div>

          {/* Entries */}
          <div className="space-y-2 flex-1">
            {entries.length === 0 ? (
              <div className="text-[9px] text-gray-600">
                No changelog entries found
              </div>
            ) : (
              entries.map((entry, index) => (
                <div
                  key={index}
                  className="text-[9px] leading-relaxed text-black"
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <span className="font-bold">{entry.type}:</span>{" "}
                      <span>{entry.description}</span>
                    </div>
                  </div>
                  <div className="text-[8px] text-gray-600 mt-0.5">
                    {entry.author} / {entry.date} / {entry.time}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

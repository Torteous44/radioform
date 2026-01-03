"use client";

import { useState, useEffect } from "react";

interface LogsProps {
  className?: string;
  onClick?: () => void;
}

interface ChangelogEntry {
  type: string;
  description: string;
  author: string;
  date: string;
  time: string;
}

export default function Logs({ className = "", onClick }: LogsProps) {
  const [entries, setEntries] = useState<ChangelogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchReleaseData = async () => {
      try {
        const response = await fetch(
          "https://api.github.com/repos/Torteous44/radioform/releases/latest"
        );
        if (!response.ok) throw new Error("Failed to fetch release data");
        
        const data = await response.json();
        const parsedEntries: ChangelogEntry[] = [];
        
        // Parse the release body
        const body = data.body || "";
        const lines = body.split("\n");
        
        // Parse date from release
        const releaseDate = new Date(data.published_at);
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
          if ((trimmed.startsWith("* ") || trimmed.startsWith("- ")) && trimmed.length > 2) {
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
        
        // Limit to 4 entries for display
        setEntries(parsedEntries.slice(0, 4));
      } catch (error) {
        console.error("Error fetching release data:", error);
        // Fallback to default entries
        setEntries([
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
        ]);
      } finally {
        setLoading(false);
      }
    };

    fetchReleaseData();
  }, []);

  return (
    <div
      className={`relative w-full max-w-[750px] aspect-[1/1.414] ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={{
        fontFamily: '"Courier New", Courier, monospace',
        filter: `
          drop-shadow(0px 1px 1px rgba(0,0,0,0.1))
          drop-shadow(0px 2px 4px rgba(0,0,0,0.08))
          drop-shadow(0px 4px 8px rgba(0,0,0,0.06))
        `,
        opacity: 1,
      }}
    >
      {/* Base paper with grid */}
      <div
        className="relative bg-white pl-10 pr-5 py-5 h-full flex flex-col"
        style={{
          backgroundColor: "#ffffff",
          backgroundImage: `
            linear-gradient(to right, rgba(0,0,0,0.08) 1px, transparent 1px),
            linear-gradient(to bottom, rgba(0,0,0,0.08) 1px, transparent 1px)
          `,
          backgroundSize: "18px 18px",
        }}
      >
        {/* Binder holes on left side */}
        <div className="absolute left-3 top-0 bottom-0 flex flex-col justify-evenly py-6 z-[15]">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="w-4 h-4 rounded-full bg-gray-200 border border-gray-300"
              style={{
                boxShadow: "inset 1px 1px 2px rgba(0,0,0,0.15), inset -1px -1px 1px rgba(255,255,255,0.5)",
              }}
            />
          ))}
        </div>
        {/* Aging layer: corner wear */}
        <div
          className="absolute inset-0 pointer-events-none z-[1]"
          style={{
            background: `
              radial-gradient(
                ellipse 60px 60px at 8px 8px,
                rgba(255, 245, 230, 0.3) 0%,
                transparent 70%
              ),
              radial-gradient(
                ellipse 50px 50px at calc(100% - 8px) 8px,
                rgba(255, 245, 230, 0.2) 0%,
                transparent 60%
              ),
              radial-gradient(
                ellipse 70px 70px at 8px calc(100% - 8px),
                rgba(255, 248, 235, 0.25) 0%,
                transparent 70%
              ),
              radial-gradient(
                ellipse 80px 80px at calc(100% - 8px) calc(100% - 8px),
                rgba(255, 250, 240, 0.35) 0%,
                transparent 70%
              )
            `,
          }}
        />

        {/* Aging layer: edge darkening */}
        <div
          className="absolute inset-0 pointer-events-none z-[2]"
          style={{
            background: `
              linear-gradient(90deg, rgba(0,0,0,0.03) 0%, transparent 3%),
              linear-gradient(270deg, rgba(0,0,0,0.02) 0%, transparent 2%),
              linear-gradient(0deg, rgba(0,0,0,0.03) 0%, transparent 3%),
              linear-gradient(180deg, rgba(0,0,0,0.02) 0%, transparent 2%)
            `,
          }}
        />

        {/* Aging layer: noise/grain */}
        <div
          className="absolute inset-0 pointer-events-none z-[3]"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
            opacity: 0.04,
            mixBlendMode: "multiply",
          }}
        />

        {/* Content */}
        <div className="relative z-[10] flex flex-col flex-1">
          {/* Header */}
          <div className="flex justify-between items-center mb-4">
            <h1 className="text-sm font-bold text-black underline">
              VIEW GITHUB
            </h1>
            <h1
              className="text-sm font-bold tracking-widest text-black"
              style={{ letterSpacing: "0.2em" }}
            >
              CHANGELOG
            </h1>
          </div>

          {/* Entries */}
          <div className="space-y-4 flex-1">
            {loading ? (
              <div className="text-[11px] text-gray-600">Loading changelog...</div>
            ) : entries.length === 0 ? (
              <div className="text-[11px] text-gray-600">No changelog entries found</div>
            ) : (
              entries.map((entry, index) => (
                <div key={index} className="text-[11px] leading-relaxed">
                  <div className="flex justify-between items-start">
                    <div>
                      <span className="font-bold">{entry.type}:</span>{" "}
                      <span>{entry.description}</span>
                    </div>
                  </div>
                  <div className="text-[10px] text-gray-600 mt-0.5">
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

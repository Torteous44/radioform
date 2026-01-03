"use client";

interface LogsProps {
  className?: string;
  onClick?: () => void;
}

export default function Logs({ className = "", onClick }: LogsProps) {
  const entries = [
    {
      type: "feat",
      description: "add invisible audio sweetening",
      author: "Max de Castro",
      date: "Jan 3, 2026",
      time: "1:30 pm",
    },
    {
      type: "fix",
      description: "move SSE headers for Linux compatibility",
      author: "Pavlos Team",
      date: "Jan 2, 2026",
      time: "4:00 pm",
    },
    {
      type: "refactor",
      description: "separate DSP module from core",
      author: "Engineering",
      date: "Jan 1, 2026",
      time: "5:00 pm",
    },
    {
      type: "docs",
      description: "update API documentation",
      author: "Team",
      date: "Dec 30, 2025",
      time: "2:00 pm",
    },
  ];

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
            {entries.map((entry, index) => (
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
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

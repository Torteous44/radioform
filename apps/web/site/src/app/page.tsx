"use client";

import { useState } from "react";
import Folder from "@/components/Folder";
import Card from "@/components/Card";
import Logs from "@/components/Logs";
import Instructions from "@/components/Instructions";

// CONFIG
const C = {
  expandOffset: 440,
  instructionsExpandOffset: 600, // Larger offset when instructions are expanded to move folder down more

  folder:       { bottom: -260, z: 10 },
  card:         { bottom: 40, z: 5 },
  logs:         { top: 20, x: 24, rotation: 12, scale: 0.85, scaleExp: 1.3, z: 4 },
  instructions: { top: 24, x: 164, rotation: -12, scale: 0.65, scaleExp: 1.2, z: 4 },
};

type Expanded = null | "card" | "logs" | "instructions";

export default function Home() {
  const [exp, setExp] = useState<Expanded>(null);
  const anyExp = exp !== null;
  const offset = anyExp 
    ? (exp === "instructions" ? C.instructionsExpandOffset : C.expandOffset)
    : 0;

  const nav = (n: 1 | 2 | 3 | 4) => setExp({ 1: null, 2: "card", 3: "logs", 4: "instructions" }[n] as Expanded);
  const current = exp === "card" ? 2 : exp === "logs" ? 3 : exp === "instructions" ? 4 : 1;

  return (
    <div className="h-screen w-screen paper-texture relative overflow-hidden">
      {/* Nav */}
      <div className="absolute top-4 left-4 z-30 flex flex-col gap-1">
        {[1, 2, 3, 4].map((n) => (
          <button
            key={n}
            onClick={() => nav(current === n && n !== 1 ? 1 : n as 1 | 2 | 3 | 4)}
            className="text-xs font-mono transition-all duration-300 cursor-pointer text-left w-8"
            style={{ color: current === n ? "#000" : "#999", fontFamily: '"Courier New", monospace' }}
          >
            {current === n && n !== 1 ? "<-" : n}
          </button>
        ))}
      </div>

      {/* Card */}
      <div
        className="fixed left-1/2 transition-all duration-300 card-hover"
        data-expanded={exp === "card" || undefined}
        style={{
          zIndex: C.card.z,
          top: exp === "card" ? "50%" : undefined,
          bottom: exp === "card" ? undefined : C.card.bottom,
          transform: exp === "card"
            ? "translate(-50%, -50%)"
            : `translateX(-50%) translateY(${anyExp ? offset : 0}px)`,
          transformOrigin: "bottom center",
          pointerEvents: anyExp && exp !== "card" ? "none" : "auto",
        }}
      >
        <Card onClick={() => !anyExp && setExp("card")} />
      </div>

      {/* Logs */}
      <div
        className="fixed left-1/2 transition-all duration-300 logs-hover"
        data-expanded={exp === "logs" || undefined}
        style={{
          zIndex: C.logs.z,
          top: exp === "logs" ? "50%" : C.logs.top,
          transform: exp === "logs"
            ? `translate(-50%, -50%) scale(${C.logs.scaleExp})`
            : `translateX(${C.logs.x}px) translateY(${anyExp ? offset : 0}px) rotate(${C.logs.rotation}deg) scale(${C.logs.scale})`,
          transformOrigin: exp === "logs" ? "center" : "top left",
          pointerEvents: anyExp && exp !== "logs" ? "none" : "auto",
        }}
      >
        <Logs onClick={() => !anyExp && setExp("logs")} />
      </div>

      {/* Instructions */}
      <div
        className="fixed right-1/2 transition-all duration-300 instructions-hover"
        data-expanded={exp === "instructions" || undefined}
        style={{
          zIndex: C.instructions.z,
          top: exp === "instructions" ? "50%" : C.instructions.top,
          transform: exp === "instructions"
            ? `translate(50%, -50%) scale(${C.instructions.scaleExp})`
            : `translateX(${C.instructions.x}px) translateY(${anyExp ? offset : 0}px) rotate(${C.instructions.rotation}deg) scale(${C.instructions.scale})`,
          transformOrigin: exp === "instructions" ? "center" : "top right",
          pointerEvents: anyExp && exp !== "instructions" ? "none" : "auto",
        }}
      >
        <Instructions onClick={() => !anyExp && setExp("instructions")} />
      </div>

      {/* Folder */}
      <Folder
        onClick={anyExp ? () => setExp(null) : undefined}
        className="absolute left-1/2 transition-transform duration-300"
        style={{
          zIndex: C.folder.z,
          bottom: C.folder.bottom,
          transform: `translateX(-50%) translateY(${offset}px)`,
        }}
      />
    </div>
  );
}

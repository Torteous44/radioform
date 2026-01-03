"use client";

import { useState } from "react";
import Folder from "@/components/Folder";
import Card from "@/components/Card";
import Logs from "@/components/Logs";

// Card scale controls  
const CARD_SCALE_DEFAULT = 1; // Scale when card is tucked in folder (smaller to fit behind folder)
const CARD_SCALE_EXPANDED = 1.05; // Scale when card is expanded
const CARD_ROTATION = -8; // Rotation angle when tucked (negative = counter-clockwise, in degrees)

// Folder position controls
const FOLDER_EXPANDED_OFFSET = 480; // How far down folder moves when expanded (in px)
const DEFAULT_Y_OFFSET = 100; // How much to push everything down in default state (in px)

// Logs position controls
const LOGS_PEEK_AMOUNT = 80; // How much of the logs is visible when tucked (in px)
const LOGS_ROTATION = 12; // Rotation angle when tucked (clockwise, in degrees)
const LOGS_RIGHT_OFFSET = -40; // Distance from right edge of folder (in px, negative = closer to folder)
const LOGS_TOP_OFFSET = -40; // Distance from top of folder (in px)
const LOGS_SCALE_DEFAULT = 0.85; // Scale when logs is tucked
const LOGS_SCALE_EXPANDED = 1.3; // Scale when logs is expanded

type ExpandedState = null | "card" | "logs";

export default function Home() {
  const [expanded, setExpanded] = useState<ExpandedState>(null);

  const isCardExpanded = expanded === "card";
  const isLogsExpanded = expanded === "logs";
  const isAnyExpanded = expanded !== null;

  const handleNavigation = (state: 1 | 2 | 3) => {
    if (state === 1) {
      setExpanded(null);
    } else if (state === 2) {
      setExpanded("card");
    } else if (state === 3) {
      setExpanded("logs");
    }
  };

  const currentState: 1 | 2 | 3 = isCardExpanded ? 2 : isLogsExpanded ? 3 : 1;

  return (
    <div className="h-screen w-screen paper-texture relative overflow-hidden">
      {/* Navigation */}
      <div className="absolute top-4 left-4 z-30 flex flex-col gap-1">
        {[1, 2, 3].map((num) => {
          const isActive = currentState === num;
          const showBack = isActive && num !== 1;
          return (
            <button
              key={num}
              onClick={() => showBack ? handleNavigation(1) : handleNavigation(num as 1 | 2 | 3)}
              className="text-xs font-mono transition-all duration-300 ease-out cursor-pointer text-left w-8"
              style={{
                color: isActive ? "#000" : "#999",
                fontFamily: '"Courier New", Courier, monospace',
              }}
            >
              <span className="inline-block transition-all duration-300 ease-out">
                {showBack ? "<-" : num}
              </span>
            </button>
          );
        })}
      </div>

      {/* Card - peeking out of folder */}
      <div
        className="fixed left-1/2 origin-bottom transition-all duration-300 ease-out card-hover z-[5]"
        data-expanded={isCardExpanded || undefined}
        style={{
          top: isCardExpanded ? "50%" : undefined,
          bottom: isCardExpanded ? undefined : `${128 - DEFAULT_Y_OFFSET}px`,
          "--card-scale": isCardExpanded ? CARD_SCALE_EXPANDED : CARD_SCALE_DEFAULT,
          "--folder-offset": isLogsExpanded ? `${FOLDER_EXPANDED_OFFSET}px` : "0px",
          transform: isCardExpanded
            ? `translate(-50%, -50%) rotate(0deg) scale(var(--card-scale))`
            : `translateX(-50%) translateY(calc(var(--hover-y, 0px) + var(--folder-offset))) rotate(${CARD_ROTATION}deg) scale(var(--card-scale))`,
          pointerEvents: isLogsExpanded ? "none" : "auto",
        } as React.CSSProperties & { "--card-scale": number; "--hover-y"?: string; "--folder-offset": string }}
      >
        <Card onClick={() => !isAnyExpanded && setExpanded("card")} />
      </div>

      {/* Logs - peeking from top right */}
      <div
        className="fixed left-2/5 transition-all duration-300 ease-out logs-hover z-[4]"
        data-expanded={isLogsExpanded || undefined}
        style={{
          // When expanded: center of screen
          // When tucked: top right corner, rotated
          top: isLogsExpanded ? "50%" : `calc(50% - 296px + ${LOGS_TOP_OFFSET + DEFAULT_Y_OFFSET}px)`,
          "--folder-offset": isCardExpanded ? `${FOLDER_EXPANDED_OFFSET}px` : "0px",
          transform: isLogsExpanded
            ? `translate(calc(10vw - 50%), -50%) rotate(0deg) scale(${LOGS_SCALE_EXPANDED})`
            : `translateX(calc(50% + ${100 + LOGS_RIGHT_OFFSET}px - ${LOGS_PEEK_AMOUNT}px)) translateY(calc(var(--logs-hover-y, 0px) + var(--folder-offset))) rotate(${LOGS_ROTATION}deg) scale(${LOGS_SCALE_DEFAULT})`,
          transformOrigin: isLogsExpanded ? "center" : "top right",
          pointerEvents: isCardExpanded ? "none" : "auto",
        } as React.CSSProperties & { "--logs-hover-y"?: string; "--folder-offset": string }}
      >
        <Logs onClick={() => !isAnyExpanded && setExpanded("logs")} />
      </div>

      {/* Folder */}
      <Folder
        onClick={isAnyExpanded ? () => setExpanded(null) : undefined}
        className="absolute left-1/2 transition-transform duration-300 ease-out z-10"
        style={{
          bottom: `${-164 - DEFAULT_Y_OFFSET}px`,
          transform: isAnyExpanded
            ? `translateX(-50%) translateY(${FOLDER_EXPANDED_OFFSET}px)`
            : "translateX(-50%)",
        }}
      />
    </div>
  );
}

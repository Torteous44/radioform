"use client";

import { useEffect, useState } from "react";
import type { ReactNode } from "react";

// CONFIG - All positions relative to folder top
const C = {
  expandOffset: 300,

  // Folder defines the anchor point - everything is relative to folder.top
  folder: {
    width: 600,
    height: 724,
    bottom: -250, // Folder bottom position (negative = partially off screen)
    z: 10,
  },

  // Offsets from folder top (negative = above folder, positive = below/into folder)
  card: { width: 480, y: -110, z: 5, hoverY: -40, scaleExp: 1.05, yExp: -35 },
  logs: { width: 450, y: -215, x: -60, rotation: 8, scale: 0.85, scaleExp: 1.2, z: 4, hoverY: -20 },
  instructions: { width: 1000, y: -220, x: 220, rotation: -8, scale: 0.55, scaleExp: 0.80, yExp: -56, z: 4, hoverY: -20 },
};

const SCENE = (() => {
  const cardHalf = C.card.width / 2;
  const logsWidth = C.logs.width * C.logs.scale;
  const instructionsWidth = C.instructions.width * C.instructions.scale;
  const left = Math.min(-cardHalf, C.logs.x, C.instructions.x - instructionsWidth);
  const right = Math.max(cardHalf, C.logs.x + logsWidth, C.instructions.x);
  const above = Math.max(-C.card.y, -C.logs.y, -C.instructions.y);
  const margin = 120;

  return {
    minScale: 0.6,
    maxScale: 1,
    width: right - left + margin,
    height: C.folder.height + C.folder.bottom + above + margin,
  };
})();

const getSceneScale = (width: number, height: number) => {
  const scale = Math.min(width / SCENE.width, height / SCENE.height);
  return Math.min(SCENE.maxScale, Math.max(SCENE.minScale, scale));
};

type Expanded = null | "card" | "logs" | "instructions";
type IntroPhase = "slideUp" | "popOut" | "done";

interface HomeClientProps {
  card: ReactNode;
  logs: ReactNode;
  instructions: ReactNode;
  folder: ReactNode;
}

export default function HomeClient({ card, logs, instructions, folder }: HomeClientProps) {
  const [sceneScale, setSceneScale] = useState(1);
  const [exp, setExp] = useState<Expanded>(null);
  const [introPhase, setIntroPhase] = useState<IntroPhase>("slideUp");

  const anyExp = exp !== null;
  const offset = anyExp ? C.expandOffset * sceneScale : 0;
  const scaled = (value: number) => value * sceneScale;
  const folderTopPx = scaled(C.folder.height + C.folder.bottom);

  useEffect(() => {
    const handleResize = () => {
      const nextScale = getSceneScale(window.innerWidth, window.innerHeight);
      setSceneScale(nextScale);
    };

    handleResize();
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // Intro animation phases
  useEffect(() => {
    // After slide up (800ms), start pop out
    const popTimer = setTimeout(() => setIntroPhase("popOut"), 600);
    // After pop out settles (1500ms total), done
    const doneTimer = setTimeout(() => setIntroPhase("done"), 1500);
    return () => {
      clearTimeout(popTimer);
      clearTimeout(doneTimer);
    };
  }, []);

  const nav = (n: 1 | 2 | 3 | 4) => setExp({ 1: null, 2: "card", 3: "instructions", 4: "logs" }[n] as Expanded);
  const current = exp === "card" ? 2 : exp === "logs" ? 4 : exp === "instructions" ? 3 : 1;

  // Calculate pop-out offsets for the expand animation
  const getPopOffset = (item: "card" | "logs" | "instructions") => {
    if (introPhase !== "popOut") return { x: 0, y: 0 };
    const offsets = {
      card: { x: 0, y: -30 },
      logs: { x: -30, y: -25 },
      instructions: { x: 30, y: -25 },
    };
    return offsets[item];
  };

  const isInteractive = introPhase === "done";

  return (
    <div className="h-screen w-screen paper-texture relative overflow-hidden">
      {/* Nav */}
      <div className="absolute top-4 left-4 z-30 flex flex-col gap-1">
        {[
          { num: 1, label: "Home" },
          { num: 2, label: "Info" },
          { num: 3, label: "Instructions" },
          { num: 4, label: "Changelog" },
          { num: 5, label: "Download", isLink: true },
        ].map(({ num, label, isLink }) => (
          isLink ? (
            <a
              key={num}
              href="https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg"
              className="text-xs font-mono transition-all duration-300 cursor-pointer text-left"
              style={{ color: "#999", fontFamily: '"Courier New", monospace', textDecoration: "none" }}
            >
              {num} {label}
            </a>
          ) : (
            <button
              key={num}
              onClick={() => nav(current === num && num !== 1 ? 1 : (num as 1 | 2 | 3 | 4))}
              className="text-xs font-mono transition-all duration-300 cursor-pointer text-left"
              style={{ color: current === num ? "#000" : "#999", fontFamily: '"Courier New", monospace' }}
            >
              {current === num && num !== 1 ? "<- Back" : `${num} ${label}`}
            </button>
          )
        ))}
      </div>

      {anyExp && (
        <button
          type="button"
          aria-label="Close expanded view"
          className="fixed inset-0 z-[2] cursor-pointer bg-transparent"
          onClick={() => setExp(null)}
        />
      )}

      {/* Intro wrapper - handles the slide up animation */}
      <div
        className={introPhase === "slideUp" ? "intro-slide-up" : ""}
        style={{
          position: "fixed",
          inset: 0,
          pointerEvents: "none",
          zIndex: 5,
        }}
      >
        {/* Card - relative to folder top */}
        <div
          className={`fixed left-1/2 card-hover cursor-pointer ${isInteractive ? "transition-all duration-300" : "intro-pop-transition"}`}
          data-expanded={exp === "card" || undefined}
          onClick={() => isInteractive && !anyExp && setExp("card")}
          style={{
            width: `${C.card.width}px`,
            zIndex: C.card.z,
            top: exp === "card"
              ? `calc(50% + ${scaled(C.card.yExp)}px)`
              : `calc(100vh - ${folderTopPx}px + ${scaled(C.card.y)}px)`,
            transform: exp === "card"
              ? `translate(-50%, -50%) scale(${C.card.scaleExp * sceneScale})`
              : `translateX(calc(-50% + ${getPopOffset("card").x}px)) translateY(calc(var(--hover-y, 0px) + ${offset}px + ${getPopOffset("card").y}px)) scale(${sceneScale})`,
            transformOrigin: exp === "card" ? "center" : "top center",
            pointerEvents: anyExp && exp !== "card" ? "none" : !isInteractive ? "none" : "auto",
          }}
        >
          {card}
        </div>

        {/* Logs - relative to folder top */}
        <div
          className={`fixed left-1/2 logs-hover cursor-pointer ${isInteractive ? "transition-all duration-300" : "intro-pop-transition"}`}
          data-expanded={exp === "logs" || undefined}
          onClick={() => isInteractive && !anyExp && setExp("logs")}
          style={{
            width: `${C.logs.width}px`,
            zIndex: C.logs.z,
            top: exp === "logs" ? "50%" : `calc(100vh - ${folderTopPx}px + ${scaled(C.logs.y)}px)`,
            transform: exp === "logs"
              ? `translate(-50%, -50%) scale(${C.logs.scaleExp * sceneScale})`
              : `translateX(calc(${scaled(C.logs.x)}px + ${getPopOffset("logs").x}px)) translateY(calc(var(--logs-hover-y, 0px) + ${offset}px + ${getPopOffset("logs").y}px)) rotate(${C.logs.rotation}deg) scale(${C.logs.scale * sceneScale})`,
            transformOrigin: exp === "logs" ? "center" : "top left",
            pointerEvents: anyExp && exp !== "logs" ? "none" : !isInteractive ? "none" : "auto",
          }}
        >
          {logs}
        </div>

        {/* Instructions - relative to folder top */}
        <div
          className={`fixed right-1/2 instructions-hover cursor-pointer ${isInteractive ? "transition-all duration-300" : "intro-pop-transition"}`}
          data-expanded={exp === "instructions" || undefined}
          onClick={() => isInteractive && !anyExp && setExp("instructions")}
          style={{
            width: `${C.instructions.width}px`,
            zIndex: C.instructions.z,
            top: exp === "instructions"
              ? `calc(50% + ${scaled(C.instructions.yExp)}px)`
              : `calc(100vh - ${folderTopPx}px + ${scaled(C.instructions.y)}px)`,
            transform: exp === "instructions"
              ? `translate(50%, -50%) scale(${C.instructions.scaleExp * sceneScale})`
              : `translateX(calc(${scaled(C.instructions.x)}px + ${getPopOffset("instructions").x}px)) translateY(calc(var(--instructions-hover-y, 0px) + ${offset}px + ${getPopOffset("instructions").y}px)) rotate(${C.instructions.rotation}deg) scale(${C.instructions.scale * sceneScale})`,
            transformOrigin: exp === "instructions" ? "center" : "top right",
            pointerEvents: anyExp && exp !== "instructions" ? "none" : !isInteractive ? "none" : "auto",
          }}
        >
          {instructions}
        </div>

        {/* Folder - the anchor */}
        <div
          className={`absolute left-1/2 ${anyExp ? "cursor-pointer" : ""} ${isInteractive ? "transition-transform duration-300" : ""}`}
          onClick={anyExp ? () => setExp(null) : undefined}
          style={{
            zIndex: C.folder.z,
            bottom: scaled(C.folder.bottom),
            transform: `translateX(-50%) translateY(${offset}px) scale(${sceneScale})`,
            transformOrigin: "bottom center",
            pointerEvents: anyExp ? "auto" : "none",
          }}
        >
          {folder}
        </div>
      </div>
    </div>
  );
}

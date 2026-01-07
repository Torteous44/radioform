"use client";

import { useEffect, useState } from "react";
import type { ReactNode, CSSProperties } from "react";
import { throttle } from "@/utils/debounce";

// =============================================================================
// CONFIG - All positioning values in one place
// =============================================================================

const CONFIG = {
  folder: {
    width: 600,
    height: 724,
    bottomOffset: -200, // How far below viewport bottom (negative = partially off screen)
  },

  // Offsets relative to folder top (negative = above folder)
  card: {
    width: 480,
    offsetY: 700,
    mobileOffsetY: 1200,
    offsetX: 0,
    mobileOffsetX: 0,
    rotation: 0,
    baseScale: 1,
    expandedScale: 1.2,
    expandedOffsetY: -270, // Adjust expanded Y position (negative = higher)
    hoverLift: 40,
  },

  logs: {
    width: 450,
    offsetY: 400,
    mobileOffsetY: 502,
    offsetX: 100,
    mobileOffsetX: 110,
    rotation: 8,
    baseScale: 0.85,
    expandedScale: 1.2,
    expandedOffsetY: -100, // Adjust expanded Y position (negative = higher)
    hoverLift: 20,
  },

  instructions: {
    width: 1000,
    offsetY: 170,
    mobileOffsetY: 1200,
    offsetX: -40,
    mobileOffsetX: -40,
    rotation: -8,
    baseScale: 0.55,
    expandedScale: 1,
    mobileExpandedScale: 0.35,
    expandedOffsetY: -150, // Adjust expanded Y position (negative = higher)
    hoverLift: 20,
  },

  expandOffset: 400, // How far folder slides down when expanded
  mobileExpandOffset: 400, // More slide on mobile

  zIndex: {
    logs: 1,
    instructions: 2,
    card: 3,
    folder: 4,
  },

  // Scale bounds
  minScale: 0.5,
  maxScale: 1,

  // Scene dimensions for scale calculation
  sceneWidth: 1000,
  sceneHeight: 900,

  transition: {
    duration: 300,
    easing: "cubic-bezier(0.4, 0, 0.2, 1)",
  },
} as const;

// =============================================================================
// TYPES
// =============================================================================

type Expanded = null | "card" | "logs" | "instructions";

interface HomeClientProps {
  card: ReactNode;
  logs: ReactNode;
  instructions: ReactNode;
  folder: ReactNode;
}

interface StyleContext {
  scale: number;
  expanded: Expanded;
  hovered: Expanded;
  isMobile: boolean;
  viewportWidth: number;
  viewportHeight: number;
}

// =============================================================================
// HOOKS
// =============================================================================

function useViewport(): {
  scale: number;
  width: number;
  height: number;
  isMobile: boolean;
} {
  const [state, setState] = useState({
    scale: 1,
    width: 1200,
    height: 800,
    isMobile: false,
  });

  useEffect(() => {
    const calculate = () => {
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const margin = 120;

      const scaleX = (vw - margin) / CONFIG.sceneWidth;
      const scaleY = (vh - margin) / CONFIG.sceneHeight;
      const scale = Math.min(
        CONFIG.maxScale,
        Math.max(CONFIG.minScale, Math.min(scaleX, scaleY)),
      );

      setState({ scale, width: vw, height: vh, isMobile: vw < 768 });
    };

    // Throttle resize events to fire maximum once every 150ms
    const throttledCalculate = throttle(calculate, 150);

    calculate();
    window.addEventListener("resize", throttledCalculate);
    return () => window.removeEventListener("resize", throttledCalculate);
  }, []);

  return state;
}

// =============================================================================
// STYLE HELPERS
// =============================================================================

function getTransition(item?: "card" | "logs" | "instructions"): string {
  const { duration, easing } = CONFIG.transition;
  const base = `transform ${duration}ms ${easing}`;
  // Add position transition for items that animate their left/right position
  if (item === "logs") {
    return `${base}, left ${duration}ms ${easing}`;
  }
  if (item === "instructions") {
    return `${base}, right ${duration}ms ${easing}`;
  }
  return base;
}

function getFolderStyle({
  scale,
  expanded,
  isMobile,
}: Omit<
  StyleContext,
  "hovered" | "viewportWidth" | "viewportHeight"
>): CSSProperties {
  const expandOffset = isMobile
    ? CONFIG.mobileExpandOffset
    : CONFIG.expandOffset;
  const slideY = expanded ? expandOffset * scale : 0;

  return {
    position: "relative",
    width: `${CONFIG.folder.width * scale}px`,
    height: `${CONFIG.folder.height * scale}px`,
    transform: `translateY(${slideY}px)`,
    transition: getTransition(),
    zIndex: CONFIG.zIndex.folder,
  };
}

// Scene anchor wrapper style - provides explicit height matching folder
function getSceneAnchorStyle(scale: number): CSSProperties {
  return {
    bottom: CONFIG.folder.bottomOffset * scale,
    height: `${CONFIG.folder.height * scale}px`,
  };
}

function getItemStyle(
  item: "card" | "logs" | "instructions",
  {
    scale,
    expanded,
    hovered,
    isMobile,
    viewportWidth,
    viewportHeight,
  }: StyleContext,
): CSSProperties {
  const cfg = CONFIG[item];
  const isExpanded = expanded === item;
  const isHovered = hovered === item && !expanded;
  const expandOffset = isMobile
    ? CONFIG.mobileExpandOffset
    : CONFIG.expandOffset;
  const transition = getTransition(item);

  // Calculate expanded scale
  let expandedScale: number;
  if (item === "instructions" && isMobile) {
    expandedScale = Math.min(
      CONFIG.instructions.mobileExpandedScale,
      (viewportWidth - 32) / cfg.width,
    );
  } else {
    expandedScale = cfg.expandedScale * scale;
  }

  // Common values
  const bottom = `${CONFIG.folder.height * scale}px`;
  const width = `${cfg.width}px`;

  // When this item is expanded, calculate transform to center it in viewport
  if (isExpanded) {
    // Use mobile-specific offsets when on mobile
    const effectiveOffsetY = isMobile ? cfg.mobileOffsetY : cfg.offsetY;
    const effectiveBaseY = effectiveOffsetY * scale;
    const itemCurrentY =
      viewportHeight +
      CONFIG.folder.bottomOffset * scale -
      CONFIG.folder.height * scale -
      effectiveBaseY;
    const targetCenterY = viewportHeight / 2;
    const itemHeight =
      item === "card"
        ? cfg.width * 1.414
        : item === "logs"
          ? cfg.width * 1.214
          : cfg.width * 0.5;
    const scaledItemHeight = itemHeight * expandedScale;
    // Add expandedOffsetY for manual adjustment (negative = higher on screen)
    const translateY =
      targetCenterY - itemCurrentY - scaledItemHeight / 2 + cfg.expandedOffsetY;

    // Use consistent translateX percentage for smooth animation
    // Card and Logs use left: 50% with translateX(-50%)
    // Instructions uses right: 50% with translateX(50%)
    if (item === "instructions") {
      return {
        position: "absolute",
        right: "50%",
        bottom,
        width,
        transform: `translateX(50%) translateY(${translateY}px) rotate(0deg) scale(${expandedScale})`,
        transformOrigin: "center",
        transition,
        zIndex: CONFIG.zIndex[item],
        pointerEvents: "auto",
      };
    }

    return {
      position: "absolute",
      left: "50%",
      bottom,
      width,
      transform: `translateX(-50%) translateY(${translateY}px) rotate(0deg) scale(${expandedScale})`,
      transformOrigin: "center",
      transition,
      zIndex: CONFIG.zIndex[item],
      pointerEvents: "auto",
    };
  }

  // When another item is expanded, slide down with folder
  const slideY = expanded ? expandOffset * scale : 0;
  const hoverLift = isHovered ? cfg.hoverLift : 0;

  // Use mobile-specific offsets when on mobile
  const effectiveOffsetY = isMobile ? cfg.mobileOffsetY : cfg.offsetY;
  const effectiveOffsetX = isMobile ? cfg.mobileOffsetX : cfg.offsetX;

  const baseY = effectiveOffsetY * scale - hoverLift + slideY;
  const rotation = cfg.rotation;
  const itemScale = cfg.baseScale * scale;

  // Card: centered, no horizontal offset needed
  if (item === "card") {
    return {
      position: "absolute",
      left: "50%",
      bottom,
      width,
      transform: `translateX(-50%) translateY(${baseY}px) scale(${itemScale})`,
      transformOrigin: "top center",
      transition,
      zIndex: CONFIG.zIndex[item],
      pointerEvents: expanded ? "none" : "auto",
    };
  }

  // Logs: positioned left of center
  // Move horizontal offset from translateX to left position for smooth animation
  // translateX stays as -50% in both states, left animates from calc(50% + offset) to 50%
  if (item === "logs") {
    const horizontalOffset = effectiveOffsetX * scale;
    return {
      position: "absolute",
      left: `calc(50% + ${horizontalOffset}px)`,
      bottom,
      width,
      transform: `translateX(-50%) translateY(${baseY}px) rotate(${rotation}deg) scale(${itemScale})`,
      transformOrigin: "center",
      transition,
      zIndex: CONFIG.zIndex[item],
      pointerEvents: expanded ? "none" : "auto",
    };
  }

  // Instructions: positioned right of center
  // Move horizontal offset from translateX to right position for smooth animation
  // translateX stays as 50% in both states, right animates from calc(50% - offset) to 50%
  const horizontalOffset = effectiveOffsetX * scale;
  return {
    position: "absolute",
    right: `calc(50% - ${horizontalOffset}px)`,
    bottom,
    width,
    transform: `translateX(50%) translateY(${baseY}px) rotate(${rotation}deg) scale(${itemScale})`,
    transformOrigin: "center",
    transition,
    zIndex: CONFIG.zIndex[item],
    pointerEvents: expanded ? "none" : "auto",
  };
}

// =============================================================================
// COMPONENT
// =============================================================================

export default function HomeClient({
  card,
  logs,
  instructions,
  folder,
}: HomeClientProps) {
  const [expanded, setExpanded] = useState<Expanded>(null);
  const [hovered, setHovered] = useState<Expanded>(null);
  const {
    scale,
    width: viewportWidth,
    height: viewportHeight,
    isMobile,
  } = useViewport();

  // Nav state derived from expanded
  const navMap = { card: 2, instructions: 3, logs: 4 } as const;
  const current = expanded ? navMap[expanded] : 1;

  const handleNav = (num: 1 | 2 | 3 | 4) => {
    const expandMap: Record<number, Expanded> = {
      1: null,
      2: "card",
      3: "instructions",
      4: "logs",
    };
    setExpanded(expandMap[num]);
  };

  const styleContext: StyleContext = {
    scale,
    expanded,
    hovered,
    isMobile,
    viewportWidth,
    viewportHeight,
  };

  return (
    <div className="h-screen w-screen paper-texture relative overflow-hidden">
      {/* Nav */}
      <div className="absolute top-4 left-4 z-30 flex flex-col gap-1">
        {[
          { num: 1, label: "Home" },
          { num: 2, label: "Info" },
          { num: 3, label: "Instructions" },
          { num: 4, label: "Changelog" },
          {
            num: 5,
            label: isMobile ? "View Github" : "Download",
            isLink: true,
          },
        ].map(({ num, label, isLink }) =>
          isLink ? (
            <a
              key={num}
              href={
                isMobile
                  ? "https://github.com/Torteous44/radioform"
                  : "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg"
              }
              target={isMobile ? "_blank" : undefined}
              rel={isMobile ? "noopener noreferrer" : undefined}
              className="text-xs font-mono transition-all duration-300 cursor-pointer text-left"
              style={{
                color: "#999",
                fontFamily: "var(--font-ibm-plex-mono), monospace",
                textDecoration: "none",
              }}
            >
              {num} {label}
            </a>
          ) : (
            <button
              key={num}
              onClick={() =>
                handleNav(
                  current === num && num !== 1 ? 1 : (num as 1 | 2 | 3 | 4),
                )
              }
              className="text-xs font-mono transition-all duration-300 cursor-pointer text-left"
              style={{
                color: current === num ? "#000" : "#999",
                fontFamily: "var(--font-ibm-plex-mono), monospace",
              }}
            >
              {current === num && num !== 1 ? "<- Back" : `${num} ${label}`}
            </button>
          ),
        )}
      </div>

      {/* Close overlay when expanded */}
      {expanded && (
        <button
          type="button"
          aria-label="Close expanded view"
          className="fixed inset-0 z-0 cursor-pointer bg-transparent"
          onClick={() => setExpanded(null)}
        />
      )}

      {/* Scene anchor - positioned at bottom center with explicit height */}
      <div
        className="absolute left-1/2 -translate-x-1/2"
        style={{
          ...getSceneAnchorStyle(scale),
          zIndex: CONFIG.zIndex.folder,
        }}
      >
        {/* Folder - the visual anchor */}
        <div
          className={expanded ? "cursor-pointer" : ""}
          onClick={expanded ? () => setExpanded(null) : undefined}
          style={getFolderStyle({ scale, expanded, isMobile })}
        >
          {folder}
        </div>

        {/* Card */}
        <div
          className="cursor-pointer"
          style={getItemStyle("card", styleContext)}
          onClick={() => !expanded && setExpanded("card")}
          onMouseEnter={() => setHovered("card")}
          onMouseLeave={() => setHovered(null)}
        >
          {card}
        </div>

        {/* Logs */}
        <div
          className="cursor-pointer"
          style={getItemStyle("logs", styleContext)}
          onClick={() => !expanded && setExpanded("logs")}
          onMouseEnter={() => setHovered("logs")}
          onMouseLeave={() => setHovered(null)}
        >
          {logs}
        </div>

        {/* Instructions */}
        <div
          className="cursor-pointer"
          style={getItemStyle("instructions", styleContext)}
          onClick={() => !expanded && setExpanded("instructions")}
          onMouseEnter={() => setHovered("instructions")}
          onMouseLeave={() => setHovered(null)}
        >
          {instructions}
        </div>
      </div>
    </div>
  );
}

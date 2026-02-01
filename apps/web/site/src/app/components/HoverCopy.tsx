"use client";

import { useRef, useState } from "react";

const VIDEOS = {
  menubar:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614903/mb_1_mqccrc.mp4",
  presets:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-preset_1_y7vonk.mp4",
  custom:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-custom_1_psrdyb.mp4",
};

interface HoverState {
  visible: boolean;
  src: string;
  x: number;
  y: number;
}

export default function HoverCopy() {
  const [hoverState, setHoverState] = useState<HoverState>({
    visible: false,
    src: "",
    x: 0,
    y: 0,
  });
  const rafRef = useRef<number | null>(null);
  const latestPos = useRef({ x: 0, y: 0 });

  const handleHover = (src: string) => {
    setHoverState((prev) =>
      prev.visible && prev.src === src ? prev : { ...prev, visible: true, src },
    );
  };

  const handleMove = (e: React.MouseEvent) => {
    latestPos.current = { x: e.clientX, y: e.clientY };
    if (rafRef.current !== null) return;
    rafRef.current = window.requestAnimationFrame(() => {
      rafRef.current = null;
      const { x, y } = latestPos.current;
      setHoverState((prev) =>
        prev.x === x && prev.y === y ? prev : { ...prev, x, y },
      );
    });
  };

  const handleLeave = () => {
    setHoverState((prev) => (prev.visible ? { ...prev, visible: false } : prev));
  };

  return (
    <>
      <div className="hidden md:block">
        <div
          className="fixed z-50 pointer-events-none transition-all duration-200 ease-out"
          style={{
            left: `${hoverState.x}px`,
            top: `${hoverState.y}px`,
            transform: "translate(16px, -50%)",
            opacity: hoverState.visible ? 1 : 0,
            scale: hoverState.visible ? "1" : "0.95",
          }}
        >
          <div className="bg-white border border-neutral-200 rounded overflow-hidden shadow-lg w-[200px] h-[200px]">
            {hoverState.visible && hoverState.src ? (
              <video
                key={hoverState.src}
                src={hoverState.src}
                autoPlay
                loop
                muted
                playsInline
                className="w-full h-full object-cover"
              />
            ) : null}
          </div>
        </div>
      </div>
      <p>
        It tucks into your{" "}
        <span
          className="md:underline md:cursor-pointer"
          onMouseEnter={() => handleHover(VIDEOS.menubar)}
          onMouseMove={handleMove}
          onMouseLeave={handleLeave}
        >
          menubar
        </span>{" "}
        and stays out of your way. Pick from{" "}
        <span
          className="md:underline md:cursor-pointer"
          onMouseEnter={() => handleHover(VIDEOS.presets)}
          onMouseMove={handleMove}
          onMouseLeave={handleLeave}
        >
          ready-made presets
        </span>{" "}
        or{" "}
        <span
          className="md:underline md:cursor-pointer"
          onMouseEnter={() => handleHover(VIDEOS.custom)}
          onMouseMove={handleMove}
          onMouseLeave={handleLeave}
        >
          craft your own EQ curves
        </span>{" "}
        for different gear—your studio monitors, your AirPods, your living room
        setup.
      </p>
    </>
  );
}

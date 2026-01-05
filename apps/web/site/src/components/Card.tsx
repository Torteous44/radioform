"use client";

import { useState, useEffect, memo } from "react";
import Image from "next/image";
import Polaroid from "./Polaroid";

interface CardProps {
  className?: string;
  onClick?: () => void;
}

interface HoverTooltipProps {
  src: string;
  alt: string;
  text?: string;
  x: number;
  y: number;
  visible: boolean;
}

const HoverTooltip = memo(function HoverTooltip({ src, alt, text, x, y, visible }: HoverTooltipProps) {
  if (!visible) return null;

  const isVideo = src.endsWith('.mp4') || src.includes('video/upload');
  const isTextOnly = !!text;

  return (
    <div
      className="absolute z-[100] pointer-events-none"
      style={{
        left: `${x}px`,
        top: `${y}px`,
        transform: "translate(10px, -50%)",
      }}
    >
      <div
        className={`bg-white border-2 border-white overflow-hidden ${isTextOnly ? 'px-4 py-2' : 'w-[179px] h-[179px]'}`}
        style={{
          boxShadow: "0 4px 12px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.1)",
        }}
      >
        {isTextOnly ? (
          <span
            className="text-[12px] font-normal tracking-wider text-gray-600"
            style={{
              fontFamily: "var(--font-ibm-plex-mono), monospace",
              letterSpacing: "0.1em",
            }}
          >
            {text}
          </span>
        ) : isVideo ? (
          <video
            key={src}
            src={src}
            autoPlay
            loop
            muted
            playsInline
            className="w-full h-full object-cover"
          />
        ) : (
          <Image
            src={src}
            alt={alt}
            width={179}
            height={179}
            className="w-full h-full object-cover"
          />
        )}
      </div>
    </div>
  );
});

export default function Card({ className = "", onClick }: CardProps) {
  const [hoverState, setHoverState] = useState<{
    visible: boolean;
    src: string;
    alt: string;
    text?: string;
    x: number;
    y: number;
  }>({
    visible: false,
    src: "",
    alt: "",
    text: undefined,
    x: 0,
    y: 0,
  });

  const handleTextHover = (
    e: React.MouseEvent<HTMLSpanElement | HTMLAnchorElement>,
    imageSrc: string,
    imageAlt: string,
    text?: string
  ) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const cardRect = e.currentTarget.closest('[data-card-container]')?.getBoundingClientRect();
    if (!cardRect) return;

    setHoverState({
      visible: true,
      src: imageSrc,
      alt: imageAlt,
      text: text,
      x: rect.right - cardRect.left,
      y: rect.top - cardRect.top + rect.height / 2,
    });
  };

  const handleTextLeave = () => {
    setHoverState((prev) => ({ ...prev, visible: false }));
  };

  // Preload all hover media after component mounts
  useEffect(() => {
    const mediaUrls = [
      "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614903/mb_1_mqccrc.mp4",
      "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-preset_1_y7vonk.mp4",
      "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-custom_1_psrdyb.mp4",
    ];

    // Preload images
    mediaUrls.forEach((url) => {
      if (url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.avif')) {
        const img = document.createElement('img');
        img.src = url;
      } else if (url.endsWith('.mp4') || url.includes('video/upload')) {
        // Preload videos
        const video = document.createElement('video');
        video.src = url;
        video.preload = 'auto';
        video.muted = true;
        // Add to DOM but hide it
        video.style.display = 'none';
        video.style.position = 'absolute';
        video.style.width = '1px';
        video.style.height = '1px';
        document.body.appendChild(video);
        // Remove after a delay to free memory
        setTimeout(() => {
          if (document.body.contains(video)) {
            document.body.removeChild(video);
          }
        }, 30000); // Remove after 30 seconds
      }
    });
  }, []);

  return (
    <div
      data-card-container
      className={`relative w-full max-w-[480px] aspect-[1/1.414] p-6 ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={{
        backgroundColor: "#ffffff",
        fontFamily: "var(--font-ibm-plex-mono), monospace",
        boxShadow: `
          inset 0px 1px 2px rgba(0,0,0,0.05),
          inset 0px -1px 1px rgba(0,0,0,0.03)
        `,
        filter: `
          drop-shadow(0px 1px 1px rgba(0,0,0,0.1))
          drop-shadow(0px 2px 4px rgba(0,0,0,0.08))
          drop-shadow(0px 4px 8px rgba(0,0,0,0.06))
        `,
        opacity: 1,
      }}
    >
      <HoverTooltip
        src={hoverState.src}
        alt={hoverState.alt}
        text={hoverState.text}
        x={hoverState.x}
        y={hoverState.y}
        visible={hoverState.visible}
      />
      {/* Polaroid attached to top right */}
      <div className="absolute top-[-32px] right-[-48px] z-20">
        {/* Paperclip on top */}
        <Image
          src="/paperclip.avif"
          alt="Paperclip"
          width={64}
          height={64}
          className="absolute top-[12px] left-9/12 -translate-x-1/2 rotate-[-50deg] z-30 w-16 h-auto"
        />
        <Polaroid
          src="/radioform.avif"
          alt="Attached photo"
          className="scale-[0.5] origin-top-right top-[36px] right-[36px] rotate-[5deg]"
        />
      </div>

      {/* Content */}
      <div className="relative z-10 h-full flex flex-col text-black">
        {/* MEMO Header */}
        <div className="text-left mb-4">
          <h1
            className="text-base font-bold tracking-widest mb-3"
            style={{ letterSpacing: "0.0em" }}
          >
            An EQ App that just works.
          </h1>

          <div className="space-y-0 text-[12px]">
            <p>
              <span className="inline-block w-14">TO:</span>MacOS users
            </p>
            <p>
              <span className="inline-block w-14">FROM:</span>The Pavlos Company RSA
            </p>
            <p>
              <span className="inline-block w-14">DATE:</span>January 5, 2026
            </p>
            <p>
              <span className="inline-block w-14">RE:</span>Quarterly Update
            </p>
          </div>
        </div>

        {/* Divider line */}
        <div
          className="w-full mb-4"
          style={{
            borderTop: "1px solid #222",
          }}
        />

        {/* Body */}
        <div className="text-left space-y-3 text-[12px] leading-relaxed flex-1">
          <p>
            You&apos;ve got the headphones. You&apos;ve got the speakers. But macOS still outputs the same flat, unoptimized audio it always has.{" "}
            <a
              href="https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg"
              className="underline"
              onClick={(e) => e.stopPropagation()}
              onMouseEnter={(e) => handleTextHover(e, "", "", "DOWNLOAD")}
              onMouseLeave={handleTextLeave}
            >
              Radioform
            </a>{" "}
            is a macOS native equalizer that finally lets you shape your sound system-wide.
          </p>

          <p>
            It tucks into your{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614903/mb_1_mqccrc.mp4", "Menubar", undefined)}
              onMouseLeave={handleTextLeave}
            >
              menubar
            </span>{" "}
            and stays out of your way. Pick from{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-preset_1_y7vonk.mp4", "Ready-made presets", undefined)}
              onMouseLeave={handleTextLeave}
            >
              ready-made presets
            </span>{" "}
            or take matters into your own hands and{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-custom_1_psrdyb.mp4", "Craft your own EQ curves", undefined)}
              onMouseLeave={handleTextLeave}
            >
              craft your own EQ curves
            </span>{" "}
            for different gear—your studio monitors, your AirPods, your living room setup. One app, every scenario.
          </p>

          <p>
            Built in Swift,{" "}
            <a
              href="https://github.com/Torteous44/radioform"
              target="_blank"
              rel="noopener noreferrer"
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "", "", "VIEW GITHUB")}
              onMouseLeave={handleTextLeave}
            >
              fully open source
            </a>
            , and completely free. No bloat, no secrets, no price tag.
          </p>

          <p className="inline-block">
            <a
              href="https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg"
              className="relative z-20 border border-gray-400 bg-white px-4 py-2 text-[12px] font-normal tracking-wider text-gray-600 hover:border-gray-600 hover:text-gray-800 hover:bg-gray-50 transition-all duration-150 cursor-pointer inline-flex items-center gap-2"
              style={{
                fontFamily: "var(--font-ibm-plex-mono), monospace",
                letterSpacing: "0.1em",
                textDecoration: "none",
              }}
              onClick={(e) => {
                e.stopPropagation();
              }}
              onMouseEnter={(e) => {
                e.stopPropagation();
              }}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" style={{ marginTop: "-2px" }}>
                <path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282"/>
              </svg>
              DOWNLOAD
            </a>
          </p>
        </div>

        {/* Logo at bottom - stamp style */}
        <div className="flex justify-end -mt-84">
          <Image
            src="/pavlos.svg"
            alt="Logo"
            width={124}
            height={124}
            className="h-18 w-auto"
            style={{
              height: "124px",
              transform: "rotate(-16deg)",
            }}
          />
        </div>
      </div>
    </div>
  );
}

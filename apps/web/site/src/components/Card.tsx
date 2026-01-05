"use client";

import { useState } from "react";
import Image from "next/image";
import Polaroid from "./Polaroid";

interface CardProps {
  className?: string;
  onClick?: () => void;
}

interface HoverTooltipProps {
  src: string;
  alt: string;
  x: number;
  y: number;
  visible: boolean;
}

function HoverTooltip({ src, alt, x, y, visible }: HoverTooltipProps) {
  if (!visible) return null;

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
        className="w-32 h-32 bg-white border-2 border-white overflow-hidden"
        style={{
          boxShadow: "0 4px 12px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.1)",
        }}
      >
        <Image
          src={src}
          alt={alt}
          width={128}
          height={128}
          className="w-full h-full object-cover"
        />
      </div>
    </div>
  );
}

export default function Card({ className = "", onClick }: CardProps) {
  const [hoverState, setHoverState] = useState<{
    visible: boolean;
    src: string;
    alt: string;
    x: number;
    y: number;
  }>({
    visible: false,
    src: "",
    alt: "",
    x: 0,
    y: 0,
  });

  const handleTextHover = (
    e: React.MouseEvent<HTMLSpanElement>,
    imageSrc: string,
    imageAlt: string
  ) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const cardRect = e.currentTarget.closest('[data-card-container]')?.getBoundingClientRect();
    if (!cardRect) return;

    setHoverState({
      visible: true,
      src: imageSrc,
      alt: imageAlt,
      x: rect.right - cardRect.left,
      y: rect.top - cardRect.top + rect.height / 2,
    });
  };

  const handleTextLeave = () => {
    setHoverState((prev) => ({ ...prev, visible: false }));
  };
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
            FOR MUSIC LOVERS
          </h1>

          <div className="space-y-0 text-[12px]">
            <p>
              <span className="inline-block w-14">TO:</span>MacOS users
            </p>
            <p>
              <span className="inline-block w-14">FROM:</span>The Pavlos Company RSA
            </p>
            <p>
              <span className="inline-block w-14">DATE:</span>January 3, 2026
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
            We know you&apos;ve bought that new{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Stereo system")}
              onMouseLeave={handleTextLeave}
            >
              stereo system
            </span>{" "}
            or{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Headphones")}
              onMouseLeave={handleTextLeave}
            >
              headphones
            </span>
            . We know you&apos;re excited. But it&apos;s time to take it to the next level. The level
            where your music starts to warm your ears like a hot shower. So let&apos;s
            make that happen.
          </p>

          <p>
            Introducing{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Radioform")}
              onMouseLeave={handleTextLeave}
            >
              Radioform
            </span>
            , the first EQ app that just works. It lives on
            your{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Menubar")}
              onMouseLeave={handleTextLeave}
            >
              menubar
            </span>
            , hidden away without interfering with your workflow. But
            it does interfere with how bad your music sounds, by making it sound
            so sweet like the Sirens from Odyssey.
          </p>

          <p>
            We built this project to be fully{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Open source")}
              onMouseLeave={handleTextLeave}
            >
              open sourced
            </span>
            , so you know what you&apos;re
            getting into. Natively built in{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "Swift")}
              onMouseLeave={handleTextLeave}
            >
              Swift
            </span>
            , this app is a performant,
            lightweight way to enjoy your music the way it was meant to be.
            Seriously, give it a go.
          </p>

          <p>
            Take back control and learn what music can sound like once you really
            have got your hands dirty. Make your own custom{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "EQ presets")}
              onMouseLeave={handleTextLeave}
            >
              EQ presets
            </span>{" "}
            or use some
            of the pre-built ones. Optimize for your home stereo, your headphones,
            or even your{" "}
            <span
              className="underline"
              onMouseEnter={(e) => handleTextHover(e, "/radioform.avif", "MacBook")}
              onMouseLeave={handleTextLeave}
            >
              MacBook
            </span>
            . Radioform is for everyone.
          </p>

          <p className="inline-block">
            <button
              className="relative z-20 border border-gray-400 bg-white px-4 py-2 text-[12px] font-normal tracking-wider text-gray-600 hover:border-gray-600 hover:text-gray-800 hover:bg-gray-50 transition-all duration-150 cursor-pointer"
              style={{
                fontFamily: "var(--font-ibm-plex-mono), monospace",
                letterSpacing: "0.1em",
              }}
              onClick={(e) => {
                e.stopPropagation();
              }}
              onMouseEnter={(e) => {
                e.stopPropagation();
              }}
            >
              DOWNLOAD
            </button>
          </p>
        </div>

        {/* Logo at bottom - stamp style */}
        <div className="flex justify-end -mt-24">
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

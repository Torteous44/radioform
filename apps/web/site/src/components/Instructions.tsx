"use client";

import Image from "next/image";

interface InstructionsProps {
  className?: string;
  onClick?: () => void;
}

export default function Instructions({ className = "", onClick }: InstructionsProps) {
  const instructions = [
    {
      image: "/instructions/frame1.png",
      caption: "Step 1: Download and install Radioform.",
    },
    {
      image: "/instructions/frame2.png",
      caption: "Step 2: Select your audio output device",
    },
    {
      image: "/instructions/frame3.png",
      caption: "Step 3: Choose a preset or create your own custom EQ",
    },
    {
      image: "/instructions/frame4.png",
      caption: "Step 4: Enjoy.",
    },
  ];

  return (
    <div
      className={`relative w-full max-w-[900px] ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={{
        fontFamily: "var(--font-ibm-plex-mono), monospace",
        filter: `
          drop-shadow(0px 1px 1px rgba(0,0,0,0.1))
          drop-shadow(0px 2px 4px rgba(0,0,0,0.08))
          drop-shadow(0px 4px 8px rgba(0,0,0,0.06))
        `,
        opacity: 1,
      }}
    >
      {/* Base paper with vintage faded background */}
      <div
        className="relative bg-white p-8 flex flex-col"
        style={{
          backgroundColor: "#faf9f6",
          backgroundImage: `
            linear-gradient(to right, rgba(0,0,0,0.03) 1px, transparent 1px),
            linear-gradient(to bottom, rgba(0,0,0,0.03) 1px, transparent 1px)
          `,
          backgroundSize: "20px 20px",
        }}
      >
        {/* Aging layer: corner wear */}
        <div
          className="absolute inset-0 pointer-events-none z-[1]"
          style={{
            background: `
              radial-gradient(
                ellipse 80px 80px at 8px 8px,
                rgba(255, 245, 230, 0.4) 0%,
                transparent 70%
              ),
              radial-gradient(
                ellipse 70px 70px at calc(100% - 8px) 8px,
                rgba(255, 245, 230, 0.3) 0%,
                transparent 60%
              ),
              radial-gradient(
                ellipse 90px 90px at 8px calc(100% - 8px),
                rgba(255, 248, 235, 0.35) 0%,
                transparent 70%
              ),
              radial-gradient(
                ellipse 100px 100px at calc(100% - 8px) calc(100% - 8px),
                rgba(255, 250, 240, 0.45) 0%,
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
              linear-gradient(90deg, rgba(0,0,0,0.02) 0%, transparent 3%),
              linear-gradient(270deg, rgba(0,0,0,0.015) 0%, transparent 2%),
              linear-gradient(0deg, rgba(0,0,0,0.02) 0%, transparent 3%),
              linear-gradient(180deg, rgba(0,0,0,0.015) 0%, transparent 2%)
            `,
          }}
        />

        {/* Aging layer: noise/grain */}
        <div
          className="absolute inset-0 pointer-events-none z-[3]"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
            opacity: 0.03,
            mixBlendMode: "multiply",
          }}
        />

        {/* Header */}
        <div className="relative z-[10] mb-6">
          <h1
            className="text-left text-[18px] font-semibold underline text-black"
            style={{
              fontFamily: "var(--font-ibm-plex-mono), monospace",
            }}
          >
            INSTRUCTIONS FOR ENJOYMENT
          </h1>
        </div>

        {/* Content */}
        <div className="relative z-[10] flex flex-row gap-4">
          {instructions.map((instruction, index) => (
            <div key={index} className="flex flex-col flex-1">
              <div className="relative mb-3 aspect-square">
                <Image
                  src={instruction.image}
                  alt={`Step ${index + 1}`}
                  width={200}
                  height={200}
                  className="w-full h-full object-cover rounded-sm"
                  style={{
                    boxShadow: "0 1px 3px rgba(0,0,0,0.12)",
                  }}
                />
              </div>
              <p
                className="text-xs leading-relaxed text-black text-left"
                style={{
                  fontFamily: "var(--font-ibm-plex-mono), monospace",
                }}
              >
                {instruction.caption}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

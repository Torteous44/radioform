"use client";

import Image from "next/image";
import { memo } from "react";

interface PolaroidProps {
  src: string;
  alt?: string;
  rotation?: number;
  className?: string;
}

export default memo(function Polaroid({
  src,
  alt = "Polaroid photo",
  rotation = -3,
  className = "",
}: PolaroidProps) {
  // Check if className already includes a rotate class
  const hasRotateClass = className.includes("rotate-");
  
  return (
    <div
      className={`group relative inline-block ${className}`}
      style={!hasRotateClass ? { transform: `rotate(${rotation}deg)` } : undefined}
    >
      {/* Main polaroid frame */}
      <div
        className="relative bg-[#fafafa] p-4 shadow-[0_4px_6px_rgba(0,0,0,0.1),0_10px_20px_rgba(0,0,0,0.15),0_20px_40px_rgba(0,0,0,0.1)]"
        style={{
          background: "linear-gradient(145deg, #ffffff 0%, #f5f5f5 50%, #eeeeee 100%)",
        }}
      >
        {/* Subtle border to add depth */}
        <div className="absolute inset-0 rounded-[1px] border border-black/5 pointer-events-none" />

        {/* Image container - square aspect ratio */}
        <div className="relative overflow-hidden bg-black aspect-square w-[300px]">
          <Image
            src={src}
            alt={alt}
            fill
            className="object-cover"
          />

          {/* Strong glossy reflection overlay */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              background: `
                linear-gradient(
                  135deg,
                  rgba(255,255,255,0.4) 0%,
                  rgba(255,255,255,0.2) 20%,
                  rgba(255,255,255,0) 40%,
                  rgba(255,255,255,0) 60%,
                  rgba(255,255,255,0.05) 80%,
                  rgba(255,255,255,0.1) 100%
                )
              `,
            }}
          />

          {/* Additional diagonal shine streak */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              background: `
                linear-gradient(
                  120deg,
                  transparent 0%,
                  transparent 30%,
                  rgba(255,255,255,0.3) 32%,
                  rgba(255,255,255,0.5) 34%,
                  rgba(255,255,255,0.3) 36%,
                  transparent 38%,
                  transparent 100%
                )
              `,
            }}
          />
        </div>

        {/* Edge highlight on frame (top-left light source) */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background: `
              linear-gradient(
                135deg,
                rgba(255,255,255,0.8) 0%,
                rgba(255,255,255,0.3) 2%,
                transparent 5%,
                transparent 95%,
                rgba(0,0,0,0.05) 100%
              )
            `,
          }}
        />

        {/* Inner shadow on frame for depth */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            boxShadow: "inset 0 0 10px rgba(0,0,0,0.03), inset 0 0 3px rgba(0,0,0,0.02)",
          }}
        />
      </div>
    </div>
  );
});

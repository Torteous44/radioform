"use client";

import Image from "next/image";
import { memo } from "react";
import { PaperTexture } from "@paper-design/shaders-react";
import styles from "./Instructions.module.css";

interface InstructionsProps {
  className?: string;
  onClick?: () => void;
}

export default memo(function Instructions({
  className = "",
  onClick,
}: InstructionsProps) {
  const instructions = [
    {
      image: "/instructions/frame1.avif",
      caption: (
        <>
          Step 1:{" "}
          <a
            href="https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg"
            className="underline"
            style={{ color: "inherit" }}
          >
            Download
          </a>{" "}
          and install Radioform.
        </>
      ),
    },
    {
      image: "/instructions/frame2.avif",
      caption: "Step 2: Select your audio output device",
    },
    {
      image: "/instructions/frame3.avif",
      caption: "Step 3: Choose a preset or create your own custom EQ",
    },
    {
      image: "/instructions/frame4.avif",
      caption: "Step 4: Enjoy.",
    },
  ];

  return (
    <div
      className={`relative w-full max-w-[900px] mx-auto ${styles.container} ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
    >
      {/* Base paper with vintage faded background */}
      <div className={`relative bg-white p-8 flex flex-col ${styles.paper}`}>
        {/* Paper texture background layer - z-0 */}
        <div className="absolute inset-0 z-0 pointer-events-none">
          <PaperTexture
            width="100%"
            height="100%"
            colorBack="#faf9f6"
            colorFront="#f0ebe0"
            contrast={0.8}
            roughness={0.6}
            fiber={0.75}
            fiberSize={0.18}
            crumples={0.25}
            crumpleSize={0.32}
            folds={0.4}
            foldCount={10}
            drops={0.15}
            fade={0.9}
            seed={82}
            scale={0.65}
            fit="cover"
          />
        </div>

        {/* Header */}
        <div className="relative z-[10] mb-6">
          <h1
            className={`text-left text-2xl font-semibold underline text-black ${styles.header}`}
          >
            INSTRUCTIONS FOR ENJOYMENT
          </h1>
        </div>

        {/* Content */}
        <div className="relative z-[10] grid grid-cols-2 md:grid-cols-4 gap-4">
          {instructions.map((instruction, index) => (
            <div key={index} className="flex flex-col flex-1">
              <div className="relative mb-3 aspect-square">
                <Image
                  src={instruction.image}
                  alt={`Step ${index + 1}`}
                  width={200}
                  height={200}
                  className={`w-full h-full object-cover rounded-sm ${styles.imageContainer}`}
                />
              </div>
              <p
                className={`text-2xl md:text-xs leading-relaxed text-black text-left ${styles.caption}`}
              >
                {instruction.caption}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
});

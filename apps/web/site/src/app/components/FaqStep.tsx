"use client";

import Image from "next/image";
import { useState } from "react";

interface FaqStepProps {
  src: string;
  width: number;
  height: number;
  alt: string;
  /** The text shown when toggled to "tell me" mode. */
  children: React.ReactNode;
}

/**
 * An FAQ answer that shows a hand-drawn sketch by default, with a toggle to
 * read the same thing in words. The swap fades quickly (see .rf-fade).
 */
export default function FaqStep({ src, width, height, alt, children }: FaqStepProps) {
  const [mode, setMode] = useState<"image" | "text">("text");

  return (
    <div className="flex flex-col items-start">
      <div key={mode} className="rf-fade w-full">
        {mode === "image" ? (
          <Image
            src={src}
            alt={alt}
            width={width}
            height={height}
            sizes="(min-width: 640px) 416px, 100vw"
            className="h-auto w-full"
          />
        ) : (
          <div className="space-y-4">{children}</div>
        )}
      </div>

      <button
        type="button"
        onClick={() => setMode((m) => (m === "image" ? "text" : "image"))}
        aria-label={mode === "image" ? "Show text" : "Show image"}
        className="mt-3 inline-flex cursor-pointer items-center gap-1.5 text-xs text-neutral-400 transition-colors hover:text-neutral-700 hover:underline"
      >
        <span key={`label-${mode}`} className="rf-fade">
          {mode === "image" ? "Tell me" : "Show me"}
        </span>
      </button>
    </div>
  );
}

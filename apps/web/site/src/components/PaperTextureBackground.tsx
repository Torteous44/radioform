"use client";

import { PaperTexture } from "@paper-design/shaders-react";

interface PaperTextureBackgroundProps {
  seed?: number;
  colorBack?: string;
  colorFront?: string;
}

export function PaperTextureBackground({
  seed = 11.5,
  colorBack = "#ffffff",
  colorFront = "#f5f3ed",
}: PaperTextureBackgroundProps) {
  return (
    <div className="absolute inset-0 z-0 pointer-events-none">
      <PaperTexture
        width="100%"
        height="100%"
        colorBack={colorBack}
        colorFront={colorFront}
        contrast={0.88}
        roughness={0.68}
        fiber={0.22}
        fiberSize={0.16}
        crumples={0.22}
        crumpleSize={0.31}
        folds={0.75}
        foldCount={10}
        drops={0.12}
        fade={0.02}
        seed={seed}
        scale={0.68}
        fit="cover"
      />
    </div>
  );
}

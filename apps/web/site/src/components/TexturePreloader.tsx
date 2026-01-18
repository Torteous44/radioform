"use client";

import { useState, useEffect, ReactNode } from "react";
import { PaperTexture } from "@paper-design/shaders-react";

interface TexturePreloaderProps {
  children: ReactNode;
}

/**
 * Preloads paper textures by rendering them offscreen before showing content.
 * This ensures WebGL shaders are compiled and ready before the user sees the page.
 */
export default function TexturePreloader({ children }: TexturePreloaderProps) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    // Give the textures a frame to initialize WebGL and compile shaders
    // Using requestAnimationFrame ensures the browser has painted the hidden textures
    const raf = requestAnimationFrame(() => {
      // Second frame to ensure shaders are fully compiled
      requestAnimationFrame(() => {
        setReady(true);
      });
    });

    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <>
      {/* Hidden preload container - renders all texture variants to warm up WebGL */}
      {!ready && (
        <div
          aria-hidden="true"
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            width: "1px",
            height: "1px",
            overflow: "hidden",
            opacity: 0,
            pointerEvents: "none",
            zIndex: -1,
          }}
        >
          {/* Card texture config */}
          <PaperTexture
            width={1}
            height={1}
            colorBack="#ffffff"
            colorFront="#f5f3ed"
            contrast={0.95}
            roughness={0.65}
            fiber={0.2}
            fiberSize={0.15}
            crumples={0.2}
            crumpleSize={0.9}
            folds={0.1}
            foldCount={10}
            drops={0.1}
            fade={0}
            seed={52}
            scale={0.7}
            fit="cover"
          />
          {/* Logs texture config */}
          <PaperTexture
            width={1}
            height={1}
            colorBack="#ffffff"
            colorFront="#f5f3ed"
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
            seed={11.5}
            scale={0.68}
            fit="cover"
          />
          {/* Instructions texture config */}
          <PaperTexture
            width={1}
            height={1}
            colorBack="#faf9f6"
            colorFront="#f0ebe0"
            contrast={0.8}
            roughness={0.6}
            fiber={0.75}
            fiberSize={0.18}
            crumples={0.25}
            crumpleSize={0.35}
            folds={0.45}
            foldCount={10}
            drops={0.15}
            fade={0.9}
            seed={82}
            scale={0.65}
            fit="cover"
          />
        </div>
      )}

      {/* Main content - fades in once textures are ready */}
      <div
        style={{
          opacity: ready ? 1 : 0,
          transition: "opacity 150ms ease-out",
        }}
      >
        {children}
      </div>
    </>
  );
}

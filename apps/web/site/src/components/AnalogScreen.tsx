'use client';

import React, { useEffect } from 'react';

interface AnalogScreenProps {
  width?: number;
  height?: number;
  text?: string;
}

export default function AnalogScreen({ width, height = 48, text = 'RadioForm is now playing' }: AnalogScreenProps) {
  // Default width: 4 buttons (48px each) + 3 gaps (12px each) = 228px
  const defaultWidth = width ?? 228;
  // Duplicate text multiple times for seamless loop
  const displayText = `${text}    `.repeat(3);
  const segmentLength = text.length + 4; // text + spacing

  useEffect(() => {
    // Inject keyframes dynamically - update if width or text changes
    const styleId = 'analog-screen-scroll-animation';
    let style = document.getElementById(styleId) as HTMLStyleElement;
    
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }
    
    // Animation: scroll from right edge to left, creating seamless loop
    // Each segment is approximately segmentLength * 0.6ch wide
    const segmentWidth = segmentLength * 0.6; // Approximate width in ch units
    style.textContent = `
      @keyframes analog-screen-scroll {
        0% {
          transform: translateX(${defaultWidth}px) translateY(-50%);
        }
        100% {
          transform: translateX(calc(-${segmentWidth}ch)) translateY(-50%);
        }
      }
    `;
  }, [defaultWidth, segmentLength]);

  return (
    <div 
      className="relative rounded-sm overflow-hidden border border-gray-700 flex items-center"
      style={{
        width: `${defaultWidth}px`,
        height: `${height}px`,
        background: 'linear-gradient(to bottom, #1a1a1a, #0a0a0a)',
        boxShadow: 'inset 0 2px 8px rgba(0, 0, 0, 0.8), inset 0 1px 2px rgba(255, 255, 255, 0.1)',
      }}
    >
      {/* LCD dot matrix pattern */}
      <div 
        className="absolute inset-0 opacity-20"
        style={{
          backgroundImage: `radial-gradient(circle, rgba(255, 0, 0, 0.3) 1px, transparent 1px)`,
          backgroundSize: '4px 4px',
          backgroundPosition: '0 0, 2px 2px',
        }}
      />
      
      {/* Subtle analog glow effect */}
      <div 
        className="absolute inset-0 opacity-30"
        style={{
          background: 'radial-gradient(circle at center, rgba(20, 20, 20, 0.5), transparent 70%)',
        }}
      />
      
      {/* Scrolling text wrapper */}
      <div 
        className="absolute inset-0 overflow-hidden z-10"
        style={{
          maskImage: 'linear-gradient(to right, transparent 0%, black 10%, black 90%, transparent 100%)',
          WebkitMaskImage: 'linear-gradient(to right, transparent 0%, black 10%, black 90%, transparent 100%)',
        }}
      >
        <div
          className="absolute whitespace-nowrap font-mono text-red-600 text-md tracking-wider"
          style={{
            textShadow: '0 0 3px rgba(255, 0, 0, 0.8)',
            animation: 'analog-screen-scroll 12s linear infinite',
            top: '50%',
            left: 0,
          }}
        >
          {displayText}
        </div>
      </div>
    </div>
  );
}


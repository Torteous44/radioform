'use client';

import React, { useState, useRef, useCallback } from 'react';

interface KnobProps {
  label: string;
  value?: number;
  minValue?: number;
  maxValue?: number;
  onChange?: (value: number) => void;
  size?: number;
}

export default function Knob({ 
  label, 
  value = 0, 
  minValue = 0, 
  maxValue = 100,
  onChange,
  size = 60 
}: KnobProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [internalValue, setInternalValue] = useState(value);
  const knobRef = useRef<HTMLDivElement>(null);
  const startXRef = useRef<number>(0);
  const startValueRef = useRef<number>(value);

  // Sync internal value with prop value when not dragging
  React.useEffect(() => {
    if (!isDragging) {
      setInternalValue(value);
      startValueRef.current = value;
    }
  }, [value, isDragging]);

  const currentValue = isDragging ? internalValue : value;
  const percentage = ((currentValue - minValue) / (maxValue - minValue)) * 100;
  // Horizontal rotation only: -90 (left) to +90 (right), avoiding bottom label area
  const rotation = (percentage / 100) * 180 - 90; // -90 to +90 degrees (180 degree range)

  // Number of dots around the top half of the knob (avoiding bottom label area)
  const dotCount = 12; // Dots on top half only
  const activeDots = Math.round((percentage / 100) * dotCount);


  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    setIsDragging(true);
    startXRef.current = e.clientX;
    startValueRef.current = currentValue;
    e.preventDefault();
  }, [currentValue]);

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!isDragging || !knobRef.current) return;
    e.preventDefault();
    
    // Use horizontal mouse movement only
    const deltaX = e.clientX - startXRef.current;
    const rect = knobRef.current.getBoundingClientRect();
    const knobWidth = rect.width;
    
    // Convert horizontal pixel movement to value change
    // Full knob width corresponds to full value range
    const valueRange = maxValue - minValue;
    const sensitivity = 2; // Adjust sensitivity
    const valueDelta = (deltaX / knobWidth) * valueRange * sensitivity;
    
    let newValue = startValueRef.current + valueDelta;
    newValue = Math.max(minValue, Math.min(maxValue, newValue));
    
    setInternalValue(newValue);
    if (onChange) {
      onChange(Math.round(newValue));
    }
  }, [isDragging, minValue, maxValue, onChange]);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  React.useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [isDragging, handleMouseMove, handleMouseUp]);

  // Calculate dot positions - only on top half (avoiding bottom label area)
  const dots = Array.from({ length: dotCount }, (_, i) => {
    // Distribute dots from -90 (left) to +90 (right) degrees
    const angle = (i / (dotCount - 1)) * 180 - 90; // -90 to +90 degrees
    const radius = size * 0.55; // Position dots further out from knob edge
    const x = Math.cos(angle * Math.PI / 180) * radius;
    const y = Math.sin(angle * Math.PI / 180) * radius;
    const isActive = i < activeDots;
    return { x, y, isActive };
  });

  return (
    <div className="flex flex-col items-center">
      {/* Knob container */}
      <div className="relative" style={{ width: `${size}px`, height: `${size}px` }}>
        {/* Dots around the knob - top half only */}
        {dots.map((dot, index) => (
          <div
            key={index}
            className="absolute rounded-full z-20"
            style={{
              left: `calc(50% + ${dot.x}px)`,
              top: `calc(50% + ${dot.y}px)`,
              width: '4px',
              height: '4px',
              transform: 'translate(-50%, -50%)',
              background: '#000000',
              opacity: dot.isActive ? 1 : 0.3,
              transition: 'opacity 0.1s',
              boxShadow: dot.isActive ? '0 0 2px rgba(0, 0, 0, 0.5)' : 'none',
            }}
          />
        ))}

        {/* Knob */}
        <div
          ref={knobRef}
          className="relative rounded-full cursor-grab active:cursor-grabbing z-10"
          style={{
            width: `${size}px`,
            height: `${size}px`,
            background: 'radial-gradient(circle at 30% 30%, #C3C2C8, #8F8E93, #7A7980)',
            border: '0.5px solid rgba(0, 0, 0, 0.3)',
            boxShadow: `
              inset 0 2px 4px rgba(255, 255, 255, 0.2),
              inset 0 -2px 4px rgba(0, 0, 0, 0.3),
              inset 2px 0 4px rgba(255, 255, 255, 0.15),
              inset -2px 0 4px rgba(0, 0, 0, 0.3),
              0 2px 4px rgba(0, 0, 0, 0.2)
            `,
            transform: `rotate(${rotation}deg)`,
            transition: isDragging ? 'none' : 'transform 0.1s',
          }}
          onMouseDown={handleMouseDown}
        >
          {/* Noise texture overlay */}
          <div
            className="absolute inset-0 rounded-full opacity-[0.4] mix-blend-overlay pointer-events-none"
            style={{
              backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='2.5' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
              backgroundSize: '40px 40px',
            }}
          />
          
          {/* Center indicator line */}
          <div
            className="absolute pointer-events-none"
            style={{
              width: '3px',
              height: `${size * 0.25}px`,
              left: '50%',
              top: `${size * 0.1}px`,
              transform: 'translateX(-50%)',
              background: 'linear-gradient(to bottom, rgba(0, 0, 0, 0.6), rgba(0, 0, 0, 0.3))',
              borderRadius: '2px',
            }}
          />
          
          {/* Subtle highlight on top */}
          <div
            className="absolute rounded-full pointer-events-none"
            style={{
              width: `${size * 0.5}px`,
              height: `${size * 0.3}px`,
              left: '50%',
              top: '20%',
              transform: 'translateX(-50%)',
              background: 'radial-gradient(ellipse, rgba(255, 255, 255, 0.15), transparent)',
            }}
          />
        </div>
      </div>

      {/* Label */}
      <div className="text-xs text-primary font-medium mt-2">
        {label}
      </div>
    </div>
  );
}


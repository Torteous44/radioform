'use client';

import React, { useState, useRef, useCallback } from 'react';

interface EQSliderProps {
  minValue: number;
  maxValue: number;
  value: number;
  onChange?: (value: number) => void;
  label?: string;
}

export default function EQSlider({ 
  minValue, 
  maxValue, 
  value: propValue, 
  onChange,
  label 
}: EQSliderProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [internalValue, setInternalValue] = useState(propValue);
  const sliderRef = useRef<HTMLDivElement>(null);

  // Sync internal value with prop value when not dragging
  React.useEffect(() => {
    if (!isDragging) {
      setInternalValue(propValue);
    }
  }, [propValue, isDragging]);

  const currentValue = isDragging ? internalValue : propValue;
  const percentage = ((currentValue - minValue) / (maxValue - minValue)) * 100;
  const position = 100 - percentage; // Invert for vertical slider (0% at top)

  const updateValue = useCallback((clientY: number) => {
    if (!sliderRef.current) return;
    
    const rect = sliderRef.current.getBoundingClientRect();
    const y = clientY - rect.top;
    const height = rect.height;
    const newPercentage = Math.max(0, Math.min(100, (y / height) * 100));
    const newValue = minValue + ((100 - newPercentage) / 100) * (maxValue - minValue);
    const roundedValue = Math.round(newValue);
    
    setInternalValue(roundedValue);
    if (onChange) {
      onChange(roundedValue);
    }
  }, [minValue, maxValue, onChange]);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    setIsDragging(true);
    e.preventDefault();
    e.stopPropagation();
  }, []);

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!isDragging) return;
    e.preventDefault();
    updateValue(e.clientY);
  }, [isDragging, updateValue]);

  const handleTrackClick = useCallback((e: React.MouseEvent) => {
    if (!isDragging) {
      updateValue(e.clientY);
    }
  }, [updateValue, isDragging]);

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

  // Generate tick marks
  const tickCount = 10;
  const ticks = Array.from({ length: tickCount + 1 }, (_, i) => {
    const tickValue = minValue + (i / tickCount) * (maxValue - minValue);
    return tickValue;
  });

  return (
    <div className="flex flex-col items-center py-4">
      {/* Top value label */}
      <div className="text-xs text-primary font-medium mb-2">
        {maxValue}
      </div>

      {/* Slider container */}
      <div 
        ref={sliderRef}
        className="relative w-16 h-64 flex items-center justify-center cursor-pointer"
        onClick={handleTrackClick}
      >

        {/* Left tick marks */}
        <div className="absolute left-1 top-0 bottom-0 flex flex-col justify-between py-2 pointer-events-none">
          {ticks.map((tick, index) => (
            <div
              key={`left-${index}`}
              className="h-px bg-gray-600 w-2"
              style={{ opacity: 0.6 }}
            />
          ))}
        </div>

        {/* Right tick marks */}
        <div className="absolute right-1 top-0 bottom-0 flex flex-col justify-between py-2 pointer-events-none">
          {ticks.map((tick, index) => (
            <div
              key={`right-${index}`}
              className="h-px bg-gray-600 w-2"
              style={{ opacity: 0.6 }}
            />
          ))}
        </div>

        {/* Track */}
        <div 
          className="absolute w-3 rounded-full pointer-events-none"
          style={{
            top: '8px',
            bottom: '8px',
            background: 'linear-gradient(to bottom, #3a3a3a, #1a1a1a)',
            border: '1px solid rgba(0, 0, 0, 0.5)',
            boxShadow: `
              inset 0 5px 10px rgba(0, 0, 0, 0.9),
              inset 0 -5px 10px rgba(0, 0, 0, 0.9),
              inset 3px 0 6px rgba(0, 0, 0, 0.7),
              inset -3px 0 6px rgba(0, 0, 0, 0.7),
              inset 0 2px 3px rgba(255, 255, 255, 0.1),
              inset 0 -2px 2px rgba(0, 0, 0, 1),
              0 1px 2px rgba(0, 0, 0, 0.3)
            `,
          }}
        />
        
        {/* Inner highlight for depth */}
        <div 
          className="absolute w-2 rounded-full pointer-events-none"
          style={{
            top: '10px',
            bottom: '10px',
            left: '50%',
            transform: 'translateX(-50%)',
            background: 'linear-gradient(to bottom, rgba(255, 255, 255, 0.08) 0%, rgba(255, 255, 255, 0.02) 20%, transparent 50%, rgba(0, 0, 0, 0.3) 100%)',
            boxShadow: `
              inset 0 2px 4px rgba(0, 0, 0, 0.4),
              inset 0 -2px 4px rgba(0, 0, 0, 0.6),
              inset 1px 0 2px rgba(0, 0, 0, 0.3),
              inset -1px 0 2px rgba(0, 0, 0, 0.3)
            `,
            borderTop: '1px solid rgba(255, 255, 255, 0.1)',
            borderBottom: '1px solid rgba(0, 0, 0, 0.5)',
          }}
        />

        {/* Slider knob */}
        <div
          className="absolute cursor-grab active:cursor-grabbing z-10"
          style={{
            top: `calc(${position}% - 12px)`,
            left: '50%',
            transform: 'translateX(-50%)',
          }}
          onMouseDown={(e) => {
            handleMouseDown(e);
            e.stopPropagation();
          }}
        >
          <div
            className="w-6 h-6 rounded-full relative"
            style={{
              background: 'linear-gradient(135deg, #1a1a1a, #0a0a0a)',
              boxShadow: `
                inset 0 1px 2px rgba(255, 255, 255, 0.2),
                inset 0 -1px 2px rgba(0, 0, 0, 0.8),
                0 2px 4px rgba(0, 0, 0, 0.5)
              `,
            }}
          >
            {/* Knob highlight */}
            <div
              className="absolute top-0 left-0 w-2 h-2 rounded-full"
              style={{
                background: 'radial-gradient(circle, rgba(255, 255, 255, 0.3), transparent)',
              }}
            />
          </div>
        </div>
      </div>

      {/* Bottom value label */}
      <div className="text-xs text-primary font-medium mt-2">
        {minValue}
      </div>

      {/* Optional label */}
      {label && (
        <div className="text-xs text-primary font-medium mt-1">
          {label}
        </div>
      )}
    </div>
  );
}


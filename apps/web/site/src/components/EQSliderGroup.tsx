'use client';

import React, { useState, useRef, useCallback } from 'react';

interface SliderConfig {
  minValue: number;
  maxValue: number;
  value: number;
  onChange: (value: number) => void;
  label?: string;
}

interface EQSliderGroupProps {
  sliders: SliderConfig[];
}

export default function EQSliderGroup({ sliders }: EQSliderGroupProps) {
  const sliderRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [draggingIndex, setDraggingIndex] = useState<number | null>(null);

  const updateValue = useCallback((sliderIndex: number, clientY: number) => {
    const sliderRef = sliderRefs.current[sliderIndex];
    if (!sliderRef) return;
    
    const config = sliders[sliderIndex];
    const rect = sliderRef.getBoundingClientRect();
    const y = clientY - rect.top;
    const height = rect.height;
    const newPercentage = Math.max(0, Math.min(100, (y / height) * 100));
    const newValue = config.minValue + ((100 - newPercentage) / 100) * (config.maxValue - config.minValue);
    const roundedValue = Math.round(newValue);
    
    config.onChange(roundedValue);
  }, [sliders]);

  const handleMouseDown = useCallback((sliderIndex: number, e: React.MouseEvent) => {
    setDraggingIndex(sliderIndex);
    e.preventDefault();
    e.stopPropagation();
  }, []);

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (draggingIndex !== null) {
      e.preventDefault();
      updateValue(draggingIndex, e.clientY);
    }
  }, [draggingIndex, updateValue]);

  const handleMouseUp = useCallback(() => {
    setDraggingIndex(null);
  }, []);

  React.useEffect(() => {
    if (draggingIndex !== null) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [draggingIndex, handleMouseMove, handleMouseUp]);

  const handleTrackClick = useCallback((sliderIndex: number, e: React.MouseEvent) => {
    if (draggingIndex === null) {
      updateValue(sliderIndex, e.clientY);
    }
  }, [updateValue, draggingIndex]);

  // Generate tick marks (same for all sliders) - volume markers
  const tickCount = 8;
  const ticks = Array.from({ length: tickCount + 1 }, (_, i) => i);

  return (
    <div className="relative flex items-end gap-4">
      {/* Connected tick mark lines - volume markers */}
      {ticks.map((tickIndex) => {
        // Slider height is h-64 (256px), with py-2 (8px) padding top and bottom on the track
        // Each slider container has py-4 (16px top and bottom) padding
        // Top label has mb-2 (8px) margin
        // Tick marks should align with the slider track area
        // Track starts 16px (py-4) + 8px (mb-2) + 8px (track top padding) = 32px from top of slider container
        const trackTop = 32; // Top of track relative to slider container
        const trackHeight = 240; // Track height (256px - 8px top - 8px bottom)
        // Position ticks higher by starting from a higher position and using less of the track
        const tickPosition = trackTop + (tickIndex / tickCount) * (trackHeight * 0.85);
        // Position from bottom: container height - tick position
        // Container height: 16px (top py-4) + 8px (mb-2) + 256px (slider) + 8px (mt-2) + 16px (bottom py-4) = 304px
        const containerHeight = 304;
        // Calculate value: middle is 0, increments of 6
        const tickValue = (tickIndex - tickCount / 2) * 6;
        
        return (
          <React.Fragment key={`tick-${tickIndex}`}>
            {/* Left value label */}
            <div
              className="absolute text-xs text-primary font-medium pointer-events-none z-0"
              style={{ 
                bottom: `${containerHeight - tickPosition - 6}px`,
                left: '-2rem',
              }}
            >
              {tickValue}
            </div>
            
            {/* Tick line */}
            <div
              className="absolute left-0 right-0 h-px bg-gray-600 pointer-events-none z-0"
              style={{ 
                bottom: `${containerHeight - tickPosition}px`,
                opacity: 0.6 
              }}
            />
            
            {/* Right value label */}
            <div
              className="absolute text-xs text-primary font-medium pointer-events-none z-0"
              style={{ 
                bottom: `${containerHeight - tickPosition - 6}px`,
                right: '-2rem',
              }}
            >
              {tickValue}
            </div>
          </React.Fragment>
        );
      })}

      {/* Individual sliders */}
      {sliders.map((config, sliderIndex) => {
        const percentage = ((config.value - config.minValue) / (config.maxValue - config.minValue)) * 100;
        const position = 100 - percentage;

        return (
          <div key={sliderIndex} className="flex flex-col items-center py-4 relative z-10">
            {/* Top frequency label */}
            {config.label && (
              <div className="text-xs text-primary font-medium mb-2">
                {config.label}
              </div>
            )}

            {/* Slider container */}
            <div 
              ref={(el) => { sliderRefs.current[sliderIndex] = el; }}
              className="relative w-16 h-64 flex items-center justify-center cursor-pointer"
              onClick={(e) => handleTrackClick(sliderIndex, e)}
            >
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
                  transition: 'none',
                }}
                onMouseDown={(e) => {
                  handleMouseDown(sliderIndex, e);
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

            {/* Bottom dB value label */}
            <div className="text-xs text-primary font-medium mt-2">
              {config.value !== undefined && config.value !== null 
                ? `${config.value >= 0 ? '+' : ''}${config.value.toFixed(1)}dB`
                : '0.0dB'}
            </div>
          </div>
        );
      })}
    </div>
  );
}


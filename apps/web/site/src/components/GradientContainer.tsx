'use client';

import React, { useState } from 'react';
import EQSliderGroup from './EQSliderGroup';
import AnalogScreen from './AnalogScreen';
import MediaButton from './MediaButton';
import Screw from './Screw';

export default function GradientContainer({ children }: { children?: React.ReactNode }) {
  const [sliderValues, setSliderValues] = useState({
    32: 10,
    64: 8,
    125: 6,
    250: 3,
    500: -1,
    1000: -2,
    2000: 1,
    4000: 5,
    8000: 7,
    16000: 9,
  });

  return (
    <div 
      className="h-[600px] w-[calc(100%+3rem)] -ml-6 relative overflow-hidden rounded-xl shadow-lg"
      style={{
        background: 'linear-gradient(to bottom, #EAF1F9, #ABAEB1)',
        boxShadow: 'inset 0 1px 0 rgba(255, 255, 255, 0.6), inset 0 -1px 0 rgba(0, 0, 0, 0.2), 0 4px 12px rgba(0, 0, 0, 0.15)',
      }}
    >
      {/* Top highlight shine */}
      <div 
        className="absolute top-0 left-0 right-0 h-32 rounded-t-xl opacity-60"
        style={{
          background: 'linear-gradient(to bottom, rgba(255, 255, 255, 0.4), transparent)',
        }}
      />
      
      {/* Noise texture overlay - increased opacity */}
      <div 
        className="absolute inset-0 opacity-[0.35] mix-blend-overlay rounded-xl"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
          backgroundSize: '150px 150px',
        }}
      />
      
      {/* Additional metallic texture layer */}
      <div 
        className="absolute inset-0 opacity-[0.2] mix-blend-soft-light rounded-xl"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter2'%3E%3CfeTurbulence type='turbulence' baseFrequency='0.5' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter2)'/%3E%3C/svg%3E")`,
          backgroundSize: '100px 100px',
        }}
      />
      
      {/* Inner shadow for depth */}
      <div 
        className="absolute inset-0 rounded-xl pointer-events-none"
        style={{
          boxShadow: 'inset 0 2px 4px rgba(0, 0, 0, 0.1), inset 0 -2px 4px rgba(0, 0, 0, 0.15)',
        }}
      />
      
      {/* Main content sections */}
      <div className="relative h-full flex flex-col">
        {/* Top section - Pills and STEREO EQ in a row */}
        <div className="relative z-10 flex items-center justify-between p-4 px-4 ">
          {/* Left pill */}
          <div 
            className="relative rounded-lg overflow-hidden"
            style={{
              backgroundColor: '#D5D4D0',
              boxShadow: 'inset 0 2px 4px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.1)',
            }}
          >
            {/* Grain texture */}
            <div 
              className="absolute inset-0 opacity-[0.3] mix-blend-overlay"
              style={{
                backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                backgroundSize: '100px 100px',
              }}
            />
            <div className="relative w-12 h-6" />
          </div>
          
          {/* STEREO EQ text */}
          <div className="font-mono font-semibold text-sm uppercase tracking-wider text-primary">
            STEREO EQ
          </div>
          
          {/* Right pill */}
          <div 
            className="relative rounded-lg overflow-hidden"
            style={{
              backgroundColor: '#D5D4D0',
              boxShadow: 'inset 0 2px 4px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.1)',
            }}
          >
            {/* Grain texture */}
            <div 
              className="absolute inset-0 opacity-[0.3] mix-blend-overlay"
              style={{
                backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                backgroundSize: '100px 100px',
              }}
            />
            <div className="relative w-12 h-6" />
          </div>
        </div>
        
        {/* Main content section - Full width */}
        <div className="flex-1 relative z-10 p-4 pt-0">
          <div className="relative rounded-lg border border-gray-400/30 flex flex-col items-center justify-center pt-4 px-4">
            {/* Screws at top corners */}
            <div className="absolute top-2 left-2">
              <Screw size={24} />
            </div>
            <div className="absolute top-2 right-2">
              <Screw size={24} />
            </div>
            
            {/* Media Buttons and Analog Screen Row */}
            {/* Width matches slider group: 10 sliders * 64px + 9 gaps * 16px = 784px */}
            <div className="w-[844px] flex items-center justify-between mb-2">
              <div className="flex items-center gap-3">
                <MediaButton icon="skipBack" />
                <MediaButton icon="skipForward" />
                <MediaButton icon="pause" />
                <MediaButton icon="play" />
              </div>
              <AnalogScreen />
            </div>
            
            {/* EQ Sliders group with connected tick marks */}
            <div className="mt-0">
              <EQSliderGroup 
                sliders={[
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[32],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 32: value })),
                    label: '32Hz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[64],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 64: value })),
                    label: '64Hz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[125],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 125: value })),
                    label: '125Hz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[250],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 250: value })),
                    label: '250Hz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[500],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 500: value })),
                    label: '500Hz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[1000],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 1000: value })),
                    label: '1kHz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[2000],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 2000: value })),
                    label: '2kHz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[4000],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 4000: value })),
                    label: '4kHz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[8000],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 8000: value })),
                    label: '8kHz'
                  },
                  {
                    minValue: -24,
                    maxValue: 24,
                    value: sliderValues[16000],
                    onChange: (value) => setSliderValues(prev => ({ ...prev, 16000: value })),
                    label: '16kHz'
                  },
                ]}
              />
            </div>
            
            {/* CHANNEL B text */}
            <div className="font-mono font-semibold text-sm uppercase tracking-wider text-primary mb-4">
              CHANNEL B
            </div>
            
            {children}
          </div>
        </div>
        
        {/* Bottom section - small height */}
        <div className="h-24 relative z-10">
        </div>
      </div>
    </div>
  );
}


"use client";

import { useState } from "react";

interface FAQItem {
  question: string;
  answer: React.ReactNode;
}

export default function FAQ({ question, answer }: FAQItem) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="border-b border-neutral-200">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full py-3 flex justify-between items-center text-left text-sm font-medium"
      >
        {question}
        <svg
          aria-hidden
          viewBox="0 0 16 16"
          className="h-[15.2px] w-[15.2px] shrink-0 text-neutral-400 transition-transform duration-300 ease-out"
          style={{
            transform: isOpen ? "rotate(45deg)" : "rotate(0deg)",
            transformOrigin: "center",
          }}
        >
          <line
            x1="8"
            y1="3"
            x2="8"
            y2="13"
            stroke="currentColor"
            strokeWidth="1.25"
            strokeLinecap="round"
          />
          <line
            x1="3"
            y1="8"
            x2="13"
            y2="8"
            stroke="currentColor"
            strokeWidth="1.25"
            strokeLinecap="round"
          />
        </svg>
      </button>
      <div
        className="grid transition-all duration-300 ease-out"
        style={{
          gridTemplateRows: isOpen ? "1fr" : "0fr",
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div className="overflow-hidden">
          <div className="text-sm text-neutral-600 leading-relaxed mb-4">
            {answer}
          </div>
        </div>
      </div>
    </div>
  );
}

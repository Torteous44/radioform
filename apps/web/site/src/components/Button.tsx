import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'filled' | 'outline';
  children: React.ReactNode;
}

export default function Button({ variant = 'filled', children, className = '', ...props }: ButtonProps) {
  const baseStyles = 'px-4 py-2 font-medium transition-colors';
  const roundedStyles = 'rounded-[20px]'; // Heavily rounded corners
  
  const variantStyles = variant === 'filled' 
    ? 'bg-primary text-white hover:opacity-90'
    : 'bg-transparent border-2 border-primary text-primary hover:bg-primary hover:text-white';
  
  return (
    <button
      className={`${baseStyles} ${roundedStyles} ${variantStyles} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}


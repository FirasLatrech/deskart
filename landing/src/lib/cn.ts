import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

/** Merges class names, letting later Tailwind utilities win over earlier ones. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

"use client"

import Link from "next/link"
import { motion } from "motion/react"
import { Menu } from "lucide-react"
import { AppleButton, LogoMark } from "./primitives"
import { DMG, REPO } from "@/lib/links"

const LINKS = [
  { label: "Shapes", href: "#shapes" },
  { label: "How it works", href: "#how" },
  { label: "Install", href: "#install" },
  { label: "Source", href: REPO },
]

export function Nav() {
  return (
    <motion.nav
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: "easeOut" }}
      className="relative z-30 mx-auto flex max-w-6xl items-center px-6 py-5"
    >
      <Link href="/" aria-label="DeskArt home" className="text-white">
        <LogoMark className="h-8 w-8" />
      </Link>

      <div className="ml-auto hidden items-center gap-8 md:flex">
        {LINKS.map((l, i) => (
          <motion.div
            key={l.label}
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 + i * 0.05, ease: "easeOut" }}
          >
            <Link
              href={l.href}
              className="text-sm font-medium text-white/70 transition-colors hover:text-white"
            >
              {l.label}
            </Link>
          </motion.div>
        ))}
      </div>

      <div className="ml-auto md:ml-8">
        <div className="hidden md:block">
          <AppleButton href={DMG} />
        </div>
        <Link
          href={DMG}
          aria-label="Download DeskArt"
          className="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 bg-white/5 md:hidden"
        >
          <Menu className="h-4 w-4" />
        </Link>
      </div>
    </motion.nav>
  )
}

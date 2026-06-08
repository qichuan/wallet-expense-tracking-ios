import { loadFont } from "@remotion/google-fonts/Inter";

export const { fontFamily } = loadFont();

// iOS dark-mode system palette
export const ios = {
  bg: "#000000",
  groupBg: "#1C1C1E",
  groupBg2: "#2C2C2E",
  separator: "rgba(84,84,88,0.6)",
  textPrimary: "#FFFFFF",
  textSecondary: "rgba(235,235,245,0.6)",
  textTertiary: "rgba(235,235,245,0.3)",
  blue: "#0A84FF",
  green: "#30D158",
  fieldBg: "#1C1C1E",
};

// CardPulse brand palette (from AppColors.swift)
export const brand = {
  bgPrimary: "#0A1428",
  bgCard: "#152238",
  accent: "#2E6DFF",
  gold: "#FFD166",
  green: "#22C55E",
  foodDrink: "#F59E0B",
  shopping: "#EC4899",
  travel: "#3B82F6",
  services: "#FACC15",
  entertainment: "#A855F7",
  health: "#EF4444",
  transport: "#14B8A6",
};

// Highlight color used to draw attention to the action target
export const HIGHLIGHT = "#FFD166";

import React from "react";
import {
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { HIGHLIGHT } from "../theme";

// A glowing rounded outline that frames the element the user must act on.
export const Highlight: React.FC<{
  x: number;
  y: number;
  width: number;
  height: number;
  radius?: number;
  at?: number;
  color?: string;
}> = ({ x, y, width, height, radius = 28, at = 0, color = HIGHLIGHT }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame - at;
  if (t < 0) return null;

  const appear = interpolate(t, [0, 0.35 * fps], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  // gentle breathing glow
  const glow = 0.5 + 0.5 * Math.sin((t / fps) * Math.PI * 2 * 0.9);

  const pad = 14;

  return (
    <div
      style={{
        position: "absolute",
        left: x - pad,
        top: y - pad,
        width: width + pad * 2,
        height: height + pad * 2,
        borderRadius: radius + pad,
        border: `6px solid ${color}`,
        boxShadow: `0 0 ${18 + glow * 26}px ${color}, inset 0 0 ${
          8 + glow * 10
        }px ${color}55`,
        opacity: appear,
        transform: `scale(${interpolate(appear, [0, 1], [1.06, 1])})`,
        zIndex: 25,
        pointerEvents: "none",
      }}
    />
  );
};

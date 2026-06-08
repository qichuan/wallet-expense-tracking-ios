import React from "react";
import {
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { HIGHLIGHT } from "../theme";

// An animated finger-tap indicator. `at` is the local frame the tap lands.
export const TapRing: React.FC<{
  x: number;
  y: number;
  at?: number;
  color?: string;
}> = ({ x, y, at = 0, color = HIGHLIGHT }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame - at;

  if (t < 0) return null;

  // Expanding pulse ring
  const pulse = interpolate(t, [0, 0.5 * fps], [0.2, 2.4], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const pulseOpacity = interpolate(t, [0, 0.5 * fps], [0.6, 0], {
    extrapolateRight: "clamp",
  });

  // The solid dot press, which fades away after the tap lands
  const press = interpolate(t, [0, 4, 10], [0, 1, 0.85], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const fadeOut = interpolate(t, [14, 24], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const ringSize = 150;

  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        zIndex: 30,
        pointerEvents: "none",
        opacity: fadeOut,
      }}
    >
      <div
        style={{
          position: "absolute",
          width: ringSize,
          height: ringSize,
          marginLeft: -ringSize / 2,
          marginTop: -ringSize / 2,
          borderRadius: "50%",
          border: `8px solid ${color}`,
          transform: `scale(${pulse})`,
          opacity: pulseOpacity,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 110,
          height: 110,
          marginLeft: -55,
          marginTop: -55,
          borderRadius: "50%",
          background: color,
          opacity: 0.32 * press,
          transform: `scale(${press})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 56,
          height: 56,
          marginLeft: -28,
          marginTop: -28,
          borderRadius: "50%",
          background: color,
          boxShadow: `0 0 28px ${color}`,
          opacity: press,
          transform: `scale(${press})`,
        }}
      />
    </div>
  );
};

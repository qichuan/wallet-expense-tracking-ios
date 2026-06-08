import React from "react";
import { interpolate, useCurrentFrame, Easing } from "remotion";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { Screen } from "../components/ui";

type Item = {
  glyph: string;
  bg: string;
  title: string;
  sub: string;
};

const ITEMS: Item[] = [
  { glyph: "🕐", bg: "#0A84FF", title: "Time of Day", sub: "At 8:00 am, weekdays" },
  { glyph: "⏰", bg: "#FF9F0A", title: "Alarm", sub: "When my alarm is stopped" },
  { glyph: "🛌", bg: "#30D158", title: "Sleep", sub: "When Wind Down starts" },
  { glyph: "📍", bg: "#0A84FF", title: "Arrive", sub: "When I arrive at the gym" },
  { glyph: "🚶", bg: "#0A84FF", title: "Leave", sub: "When I leave work" },
  { glyph: "✉️", bg: "#0A84FF", title: "Email", sub: "When I get an email" },
  { glyph: "💬", bg: "#30D158", title: "Message", sub: "When I get a message" },
  { glyph: "✈️", bg: "#FF9F0A", title: "Airplane Mode", sub: "When turned on" },
  { glyph: "📶", bg: "#0A84FF", title: "Wi-Fi", sub: "When I join a network" },
  { glyph: "🔵", bg: "#0A84FF", title: "Bluetooth", sub: "When connecting" },
  { glyph: "📡", bg: "#0A84FF", title: "NFC", sub: "When I tap an NFC tag" },
  { glyph: "🚗", bg: "#0A84FF", title: "CarPlay", sub: "When connected" },
  { glyph: "📱", bg: "#8E8E93", title: "App", sub: "When an app opens" },
  { glyph: "💳", bg: "#1d1d1f", title: "Wallet", sub: "When I tap a Wallet Card or Pass" },
  { glyph: "🔋", bg: "#30D158", title: "Battery Level", sub: "When it rises above 50%" },
];

const ROW_H = 158;
const CONTAINER_TOP = 250;
const WALLET_INDEX = 13;
const TARGET_Y = 980; // where the Wallet row should land on screen

export const S3ChooseWallet: React.FC = () => {
  const frame = useCurrentFrame();

  const scrollTo = -(WALLET_INDEX * ROW_H - (TARGET_Y - CONTAINER_TOP));
  const translateY = interpolate(frame, [6, 44], [0, scrollTo], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  return (
    <Screen>
      <StatusBar />
      <div
        style={{
          position: "absolute",
          top: 120,
          left: 0,
          right: 0,
          textAlign: "center",
          fontSize: 38,
          fontWeight: 700,
          color: "#fff",
          fontFamily,
        }}
      >
        New Automation
      </div>

      <div
        style={{
          position: "absolute",
          top: CONTAINER_TOP,
          left: 0,
          right: 0,
          bottom: 0,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 40,
            right: 40,
            transform: `translateY(${translateY}px)`,
          }}
        >
          {ITEMS.map((it, i) => {
            const isWallet = i === WALLET_INDEX;
            return (
              <div
                key={i}
                style={{
                  height: ROW_H,
                  display: "flex",
                  alignItems: "center",
                  gap: 30,
                  borderBottom: `1px solid ${ios.separator}`,
                  fontFamily,
                }}
              >
                <div
                  style={{
                    width: 78,
                    height: 78,
                    borderRadius: "50%",
                    background: it.bg,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 40,
                    flexShrink: 0,
                  }}
                >
                  {it.glyph}
                </div>
                <div style={{ flex: 1 }}>
                  <div
                    style={{
                      color: "#fff",
                      fontSize: 40,
                      fontWeight: isWallet ? 700 : 500,
                    }}
                  >
                    {it.title}
                  </div>
                  <div
                    style={{
                      color: ios.textSecondary,
                      fontSize: 30,
                      marginTop: 6,
                    }}
                  >
                    {it.sub}
                  </div>
                </div>
                <svg width="20" height="34" viewBox="0 0 20 34" fill="none">
                  <path
                    d="M3 3l13 14L3 31"
                    stroke={ios.textTertiary}
                    strokeWidth={4}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </div>
            );
          })}
        </div>
      </div>

      <Highlight
        x={40}
        y={TARGET_Y}
        width={1000}
        height={ROW_H - 12}
        radius={20}
        at={48}
        color={brand.gold}
      />
      <TapRing x={540} y={TARGET_Y + ROW_H / 2 - 6} at={64} />

      <Caption step={3} total={7} text="Scroll down and choose Wallet" />
    </Screen>
  );
};

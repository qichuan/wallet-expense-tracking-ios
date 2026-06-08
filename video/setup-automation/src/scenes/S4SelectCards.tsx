import React from "react";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { Screen, Group, Checkmark } from "../components/ui";

const Cat: React.FC<{ glyph: string; bg: string; name: string; last?: boolean }> = ({
  glyph,
  bg,
  name,
  last,
}) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 26,
      height: 110,
      padding: "0 30px",
      borderBottom: last ? "none" : `1px solid ${ios.separator}`,
      fontFamily,
    }}
  >
    <div
      style={{
        width: 64,
        height: 64,
        borderRadius: 16,
        background: bg,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 34,
      }}
    >
      {glyph}
    </div>
    <div style={{ flex: 1, color: "#fff", fontSize: 38 }}>{name}</div>
    <Checkmark />
  </div>
);

const NEXT_X = 832;
const NEXT_Y = 150;
const NEXT_W = 168;
const NEXT_H = 84;

export const S4SelectCards: React.FC = () => {
  return (
    <Screen>
      <StatusBar />

      {/* back + title + Next */}
      <div
        style={{
          position: "absolute",
          top: 150,
          left: 56,
          display: "flex",
          alignItems: "center",
          color: ios.blue,
        }}
      >
        <svg width="26" height="44" viewBox="0 0 26 44" fill="none">
          <path d="M22 6 8 22l14 16" stroke={ios.blue} strokeWidth={5} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
      <div
        style={{
          position: "absolute",
          top: 250,
          left: 56,
          fontSize: 60,
          fontWeight: 800,
          color: "#fff",
          fontFamily,
        }}
      >
        When I tap
      </div>
      <div
        style={{
          position: "absolute",
          top: NEXT_Y,
          left: NEXT_X,
          width: NEXT_W,
          height: NEXT_H,
          background: ios.blue,
          color: "#fff",
          borderRadius: 42,
          fontSize: 38,
          fontWeight: 600,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily,
        }}
      >
        Next
      </div>

      {/* Cards group */}
      <div style={{ position: "absolute", top: 380, left: 56, right: 56 }}>
        <Group>
          <Cat glyph="💳" bg="#3A3A3C" name="Ancilia Card OK-1" />
          <Cat glyph="💳" bg="#1F4DBF" name="Visa Test Card" last />
        </Group>

        <div
          style={{
            color: ios.textSecondary,
            fontSize: 28,
            fontWeight: 600,
            letterSpacing: 1,
            margin: "44px 0 18px 16px",
            fontFamily,
          }}
        >
          CATEGORY
        </div>

        <Group>
          <Cat glyph="🍽️" bg={brand.foodDrink} name="Food & Drink" />
          <Cat glyph="🛍️" bg={brand.shopping} name="Shopping" />
          <Cat glyph="✈️" bg={brand.travel} name="Travel" />
          <Cat glyph="🎟️" bg={brand.entertainment} name="Entertainment" />
          <Cat glyph="❤️" bg={brand.health} name="Health" />
          <Cat glyph="🚌" bg={brand.transport} name="Transport" last />
        </Group>
      </div>

      <Highlight x={NEXT_X} y={NEXT_Y} width={NEXT_W} height={NEXT_H} radius={42} at={36} color={brand.gold} />
      <TapRing x={NEXT_X + NEXT_W / 2} y={NEXT_Y + NEXT_H / 2} at={56} />

      <Caption step={4} total={7} text="Keep all cards & categories ticked, then tap Next" />
    </Screen>
  );
};

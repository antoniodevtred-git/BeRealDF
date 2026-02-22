/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "#0b0f1a",
        primary: "#7c3aed", // violet
        secondary: "#38bdf8", // sky
      },
    },
  },
  plugins: [],
};

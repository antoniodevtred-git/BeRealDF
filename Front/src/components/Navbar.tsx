import { Link, useLocation } from "react-router-dom";

export default function Navbar() {
  const { pathname } = useLocation();

  const linkClass = (path: string) =>
    `px-4 py-2 rounded-lg transition ${
      pathname === path
        ? "bg-primary text-white"
        : "text-gray-400 hover:text-white"
    }`;

  return (
    <nav className="w-full border-b border-white/10 backdrop-blur">
      <div className="max-w-7xl mx-auto px-6 py-4 flex gap-4">
        <Link to="/" className={linkClass("/")}>
          Markets
        </Link>

        <Link to="/borrow" className={linkClass("/borrow")}>
          Borrow
        </Link>
      </div>
    </nav>
  );
}

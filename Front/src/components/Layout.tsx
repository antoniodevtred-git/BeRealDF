import type { ReactNode } from "react"
import Header from "./Header"

type Props = {
  children: ReactNode
}

export default function Layout({ children }: Props) {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 px-6 py-10 max-w-7xl mx-auto w-full">
        {children}
      </main>
    </div>
  )
}

type Props = {
    title: string
    children: React.ReactNode
  }
  
  export default function Card({ title, children }: Props) {
    return (
      <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur p-6">
        <h2 className="text-lg font-medium mb-4">{title}</h2>
        {children}
      </div>
    )
  }
  
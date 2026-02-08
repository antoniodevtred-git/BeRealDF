import Card from "../components/Card"

export default function Home() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <Card title="Lend">
        <p className="text-sm text-gray-400">
          Deposit stablecoins and earn yield.
        </p>
      </Card>

      <Card title="Borrow">
        <p className="text-sm text-gray-400">
          Borrow against your collateral.
        </p>
      </Card>
    </div>
  )
}

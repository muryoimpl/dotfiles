# リファクタリングパターン

## 目次

1. [構造の改善](#構造の改善)
2. [命名の改善](#命名の改善)
3. [パフォーマンス最適化](#パフォーマンス最適化)

---

## 構造の改善

### メソッドの抽出

**適用場面**: コードの断片をグループ化して意味のある名前を付けられる場合。

**Before**:
```
function processOrder(order) {
  // 注文のバリデーション
  if (!order.items) throw Error("No items")
  if (!order.customer) throw Error("No customer")
  if (order.items.length === 0) throw Error("Empty order")

  // 合計の計算
  total = 0
  for item in order.items {
    total += item.price * item.quantity
  }

  // 割引の適用
  if (order.customer.isPremium) {
    total = total * 0.9
  }

  return total
}
```

**After**:
```
function processOrder(order) {
  validateOrder(order)
  total = calculateTotal(order.items)
  return applyDiscount(total, order.customer)
}
```

### クラスの抽出

**適用場面**: クラスがやることが多すぎる場合（単一責任の原則に違反）。

**兆候**:
- クラスに多くのインスタンス変数がある
- メソッドが異なる変数のサブセットで動作する
- クラス名に「And」や「Manager」が含まれる

### メソッド/変数のインライン化

**適用場面**: メソッド/変数の本体がその名前と同じくらい明確な場合。

**Before**:
```
function getRating() {
  return moreThanFiveDeliveries() ? 2 : 1
}

function moreThanFiveDeliveries() {
  return deliveries > 5
}
```

**After**:
```
function getRating() {
  return deliveries > 5 ? 2 : 1
}
```

### 条件分岐のポリモーフィズムによる置換

**適用場面**: 複数の条件分岐が同じ型/カテゴリをチェックしている場合。

**Before**:
```
function getSpeed(vehicle) {
  switch (vehicle.type) {
    case "car": return vehicle.baseSpeed
    case "bike": return vehicle.baseSpeed * 0.8
    case "truck": return vehicle.baseSpeed * 0.5
  }
}
```

**After**:
```
class Car { getSpeed() { return this.baseSpeed } }
class Bike { getSpeed() { return this.baseSpeed * 0.8 } }
class Truck { getSpeed() { return this.baseSpeed * 0.5 } }
```

### パラメータオブジェクトの導入

**適用場面**: 複数のパラメータが常に一緒に現れる場合。

**Before**:
```
function amountInvoiced(startDate, endDate) { ... }
function amountReceived(startDate, endDate) { ... }
function amountOverdue(startDate, endDate) { ... }
```

**After**:
```
function amountInvoiced(dateRange) { ... }
function amountReceived(dateRange) { ... }
function amountOverdue(dateRange) { ... }
```

### マジックナンバーの定数による置換

**適用場面**: リテラル数値の意味が明らかでない場合。

**Before**:
```
if (age >= 21) { ... }
potentialEnergy = mass * 9.81 * height
```

**After**:
```
LEGAL_DRINKING_AGE = 21
GRAVITATIONAL_CONSTANT = 9.81

if (age >= LEGAL_DRINKING_AGE) { ... }
potentialEnergy = mass * GRAVITATIONAL_CONSTANT * height
```

### ガード節（ネストした条件分岐の置換）

**適用場面**: 深いネストがコードを追いにくくしている場合。

**Before**:
```
function getPayAmount() {
  if (isDead) {
    result = deadAmount()
  } else {
    if (isSeparated) {
      result = separatedAmount()
    } else {
      if (isRetired) {
        result = retiredAmount()
      } else {
        result = normalAmount()
      }
    }
  }
  return result
}
```

**After**:
```
function getPayAmount() {
  if (isDead) return deadAmount()
  if (isSeparated) return separatedAmount()
  if (isRetired) return retiredAmount()
  return normalAmount()
}
```

---

## 命名の改善

### メソッド/変数/クラスの名前変更

**原則**:
- 名前は実装ではなく意図を表すべき
- 広く理解されていない限り略語は避ける
- ドメインの語彙を一貫して使用

**悪い例 → 良い例**:
```
d → elapsedTimeInDays
temp → customerWithHighestPurchase
calc() → calculateMonthlyRevenue()
Manager → OrderProcessor
```

### 真偽値パラメータの置換

**適用場面**: 真偽値パラメータがメソッドの動作を大きく変える場合。

**Before**:
```
setDimension(width, height, true)  // true は何を意味する？
```

**After**:
```
setDimension(width, height, { resizeContents: true })
// または
setDimensionWithContentResize(width, height)
```

### 一貫した命名規則

**ガイドライン**:
- 真偽値のメソッド/プロパティには `is/has/can` プレフィックス
- null を返す可能性がある場合は `find`、保証される場合は `get`
- ファクトリメソッドには `create/build`
- コレクションには複数形、単一アイテムには単数形

---

## パフォーマンス最適化

### 遅延初期化

**適用場面**: オブジェクトの生成がコストが高く、常に必要ではない場合。

**Before**:
```
class Report {
  constructor() {
    this.data = fetchAllData()  // 使わなくても常にフェッチ
  }
}
```

**After**:
```
class Report {
  get data() {
    if (!this._data) {
      this._data = fetchAllData()
    }
    return this._data
  }
}
```

### キャッシュ/メモ化

**適用場面**: 同じ入力で同じ計算が繰り返される場合。

**Before**:
```
function fibonacci(n) {
  if (n <= 1) return n
  return fibonacci(n - 1) + fibonacci(n - 2)
}
```

**After**:
```
cache = {}
function fibonacci(n) {
  if (n <= 1) return n
  if (cache[n]) return cache[n]
  cache[n] = fibonacci(n - 1) + fibonacci(n - 2)
  return cache[n]
}
```

### バッチ処理

**適用場面**: 複数の個別操作を組み合わせられる場合。

**Before**:
```
for user in users {
  db.insert(user)  // N 回のデータベース呼び出し
}
```

**After**:
```
db.insertMany(users)  // 1 回のデータベース呼び出し
```

### Eager Loading（N+1 クエリの修正）

**適用場面**: ループ内で関連データをクエリしている場合。

**Before**:
```
orders = Order.all()
for order in orders {
  print(order.customer.name)  // N+1 クエリ
}
```

**After**:
```
orders = Order.includes(:customer).all()  // 合計 2 クエリ
for order in orders {
  print(order.customer.name)
}
```

### 短絡評価

**適用場面**: コストの高い操作を回避できる場合。

**Before**:
```
if (isValid(data) && expensiveCheck(data)) { ... }
// 順序が重要な場合、安価なチェックを先に
```

**After**:
```
if (cheapCheck(data) && expensiveCheck(data)) { ... }
```

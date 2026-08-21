# 📚 TypeScript 5.5 — Core Offline Reference

## 🌐 Quick Summary
TypeScript adds static type definitions to JavaScript, enabling compile-time type checking and IDE IntelliSense.

## 🔑 Key Features
- **Inferred Type Predicates**: Automatic narrowing for boolean filter operations (`arr.filter((x): x is String => ...)`).
- **Control Flow Analysis**: Deep type narrowing across loops, switch statements, and destructuring.
- **Utility Types**: `Partial<T>`, `Required<T>`, `Readonly<T>`, `Record<K, T>`, `Omit<T, K>`, `Pick<T, K>`.

## 🛠️ Code Examples
```typescript
interface User {
  id: number;
  name: string;
  email?: string;
}

type ReadonlyUser = Readonly<User>;
```

// Typy 1:1 z odpowiedziami backendu.

export interface Note {
  id: string;
  title: string;
  content: string;
  pinned: boolean;
}

export interface Reminder {
  id: string;
  title: string;
  remindAt: string; // RFC3339
  done: boolean;
}

export interface EventItem {
  id: string;
  title: string;
  description: string;
  startsAt: string; // RFC3339
  endsAt: string | null;
  allDay: boolean;
}

export type Repeat = 'none' | 'daily' | 'weekly' | 'monthly';

export interface TaskItem {
  id: string;
  title: string;
  notes: string;
  dueDate: string | null; // YYYY-MM-DD
  repeat: Repeat;
  done: boolean;
}

export interface Recipe {
  id: string;
  title: string;
  description: string;
  ingredients: string;
  steps: string;
  tags: string[];
  timeMinutes: number | null;
  servings: number | null;
  favorite: boolean;
  imageFileId: string | null;
}

export interface MealPlanEntry {
  id: string;
  date: string; // YYYY-MM-DD
  mealType: string;
  recipeId: string | null;
  recipeTitle: string | null;
  note: string;
}

export interface DiaryEntry {
  id: string;
  date: string; // YYYY-MM-DD
  mealType: string;
  description: string;
  calories: number | null;
}

export interface Tx {
  id: string;
  occurredOn: string; // YYYY-MM-DD
  kind: 'expense' | 'income';
  amountGrosze: number;
  category: string;
  description: string;
  receiptFileId: string | null;
}

export interface CategorySummary {
  category: string;
  spentGrosze: number;
  limitGrosze: number; // 0 = brak limitu
}

export interface BudgetSummary {
  month: string; // YYYY-MM
  incomeGrosze: number;
  expenseGrosze: number;
  categories: CategorySummary[];
}

export interface PushSettings {
  enabled: boolean;
  serverUrl: string;
  topic: string;
  digestHour: number;
}

/// Modele danych 1:1 z odpowiedziami backendu.
library;

class Note {
  final String id;
  String title;
  String content;
  bool pinned;

  Note({required this.id, required this.title, required this.content, required this.pinned});

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        content: (j['content'] ?? '') as String,
        pinned: (j['pinned'] ?? false) as bool,
      );
}

class Reminder {
  final String id;
  String title;
  DateTime remindAt;
  bool done;

  Reminder({required this.id, required this.title, required this.remindAt, required this.done});

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        remindAt: DateTime.parse(j['remindAt'] as String).toLocal(),
        done: (j['done'] ?? false) as bool,
      );
}

class Event {
  final String id;
  String title;
  String description;
  DateTime startsAt;
  DateTime? endsAt;
  bool allDay;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    this.endsAt,
    required this.allDay,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        startsAt: DateTime.parse(j['startsAt'] as String).toLocal(),
        endsAt: j['endsAt'] == null ? null : DateTime.parse(j['endsAt'] as String).toLocal(),
        allDay: (j['allDay'] ?? false) as bool,
      );
}

class TaskItem {
  final String id;
  String title;
  String notes;
  String? dueDate; // YYYY-MM-DD
  String repeat; // none | daily | weekly | monthly
  bool done;

  TaskItem({
    required this.id,
    required this.title,
    required this.notes,
    this.dueDate,
    required this.repeat,
    required this.done,
  });

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        dueDate: j['dueDate'] as String?,
        repeat: (j['repeat'] ?? 'none') as String,
        done: (j['done'] ?? false) as bool,
      );
}

class Recipe {
  final String id;
  String title;
  String description;
  String ingredients;
  String steps;
  List<String> tags;
  int? timeMinutes;
  int? servings;
  bool favorite;
  String? imageFileId;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.tags,
    this.timeMinutes,
    this.servings,
    required this.favorite,
    this.imageFileId,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        ingredients: (j['ingredients'] ?? '') as String,
        steps: (j['steps'] ?? '') as String,
        tags: ((j['tags'] ?? []) as List).map((e) => e.toString()).toList(),
        timeMinutes: j['timeMinutes'] as int?,
        servings: j['servings'] as int?,
        favorite: (j['favorite'] ?? false) as bool,
        imageFileId: j['imageFileId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'steps': steps,
        'tags': tags,
        'timeMinutes': timeMinutes,
        'servings': servings,
        'favorite': favorite,
        'imageFileId': imageFileId,
      };
}

class MealPlanEntry {
  final String id;
  String date; // YYYY-MM-DD
  String mealType;
  String? recipeId;
  String? recipeTitle;
  String note;

  MealPlanEntry({
    required this.id,
    required this.date,
    required this.mealType,
    this.recipeId,
    this.recipeTitle,
    required this.note,
  });

  factory MealPlanEntry.fromJson(Map<String, dynamic> j) => MealPlanEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        mealType: j['mealType'] as String,
        recipeId: j['recipeId'] as String?,
        recipeTitle: j['recipeTitle'] as String?,
        note: (j['note'] ?? '') as String,
      );
}

class DiaryEntry {
  final String id;
  String date; // YYYY-MM-DD
  String mealType;
  String description;
  int? calories;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.description,
    this.calories,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        mealType: j['mealType'] as String,
        description: (j['description'] ?? '') as String,
        calories: j['calories'] as int?,
      );
}

class Tx {
  final String id;
  String occurredOn; // YYYY-MM-DD
  String kind; // expense | income
  int amountGrosze;
  String category;
  String description;
  String? receiptFileId;

  Tx({
    required this.id,
    required this.occurredOn,
    required this.kind,
    required this.amountGrosze,
    required this.category,
    required this.description,
    this.receiptFileId,
  });

  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
        id: j['id'] as String,
        occurredOn: j['occurredOn'] as String,
        kind: j['kind'] as String,
        amountGrosze: (j['amountGrosze'] as num).toInt(),
        category: (j['category'] ?? 'inne') as String,
        description: (j['description'] ?? '') as String,
        receiptFileId: j['receiptFileId'] as String?,
      );
}

class CategorySummary {
  final String category;
  final int spentGrosze;
  final int limitGrosze; // 0 = brak limitu

  CategorySummary({required this.category, required this.spentGrosze, required this.limitGrosze});

  factory CategorySummary.fromJson(Map<String, dynamic> j) => CategorySummary(
        category: j['category'] as String,
        spentGrosze: (j['spentGrosze'] as num).toInt(),
        limitGrosze: (j['limitGrosze'] as num).toInt(),
      );
}

class BudgetSummary {
  final String month; // YYYY-MM
  final int incomeGrosze;
  final int expenseGrosze;
  final List<CategorySummary> categories;

  BudgetSummary({
    required this.month,
    required this.incomeGrosze,
    required this.expenseGrosze,
    required this.categories,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
        month: j['month'] as String,
        incomeGrosze: (j['incomeGrosze'] as num).toInt(),
        expenseGrosze: (j['expenseGrosze'] as num).toInt(),
        categories: ((j['categories'] ?? []) as List)
            .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

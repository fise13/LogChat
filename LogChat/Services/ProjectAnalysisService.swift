//
//  ProjectAnalysisService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

struct ProjectAnalysis {
    let project: Project
    let progress: Double
    let completedTasks: Int
    let totalTasks: Int
    let overdueTasks: Int
    let recommendations: [String]
    let priorities: [String]
    let estimatedCompletion: Date?
}

@MainActor
class ProjectAnalysisService {
    static let shared = ProjectAnalysisService()
    
    private init() {}
    
    /// Анализирует проект и возвращает структурированный анализ
    func analyzeProject(_ project: Project) -> ProjectAnalysis {
        let tasks = project.tasks ?? []
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let totalTasks = tasks.count
        let progress = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        let now = Date()
        let overdueTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return !task.isCompleted && dueDate < now
        }.count
        
        let recommendations = generateRecommendations(project: project, tasks: tasks)
        let priorities = generatePriorities(project: project, tasks: tasks)
        let estimatedCompletion = estimateCompletion(project: project, tasks: tasks)
        
        return ProjectAnalysis(
            project: project,
            progress: progress,
            completedTasks: completedTasks,
            totalTasks: totalTasks,
            overdueTasks: overdueTasks,
            recommendations: recommendations,
            priorities: priorities,
            estimatedCompletion: estimatedCompletion
        )
    }
    
    /// Генерирует рекомендации для проекта
    private func generateRecommendations(project: Project, tasks: [ProjectTask]) -> [String] {
        var recommendations: [String] = []
        
        let overdueTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return !task.isCompleted && dueDate < Date()
        }
        
        if !overdueTasks.isEmpty {
            recommendations.append("Есть \(overdueTasks.count) просроченных задач. Рекомендуется пересмотреть приоритеты.")
        }
        
        let highPriorityIncomplete = tasks.filter { !$0.isCompleted && $0.priority >= 8 }
        if highPriorityIncomplete.count > 3 {
            recommendations.append("Много задач с высоким приоритетом. Рассмотрите возможность декомпозиции.")
        }
        
        if project.progress > 0.8 && project.status == "active" {
            recommendations.append("Проект близок к завершению. Рекомендуется провести финальную проверку.")
        }
        
        if tasks.isEmpty {
            recommendations.append("Проект не имеет задач. Добавьте задачи для лучшего отслеживания прогресса.")
        }
        
        return recommendations
    }
    
    /// Генерирует приоритеты для проекта
    private func generatePriorities(project: Project, tasks: [ProjectTask]) -> [String] {
        var priorities: [String] = []
        
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let sortedByPriority = incompleteTasks.sorted { $0.priority > $1.priority }
        
        for task in sortedByPriority.prefix(5) {
            priorities.append(task.title)
        }
        
        return priorities
    }
    
    /// Оценивает дату завершения проекта
    private func estimateCompletion(project: Project, tasks: [ProjectTask]) -> Date? {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        guard !incompleteTasks.isEmpty else {
            return Date() // Проект завершен
        }
        
        // Простая оценка на основе среднего времени выполнения задач
        // В реальной реализации можно использовать более сложные алгоритмы
        let calendar = Calendar.current
        let estimatedDays = incompleteTasks.count * 2 // Примерная оценка: 2 дня на задачу
        
        return calendar.date(byAdding: .day, value: estimatedDays, to: Date())
    }
    
    /// Создает отчет по проекту
    func generateReport(_ analysis: ProjectAnalysis) -> String {
        var report = "# Отчет по проекту: \(analysis.project.name)\n\n"
        
        report += "## Прогресс\n\n"
        report += "- Выполнено: \(analysis.completedTasks) из \(analysis.totalTasks) задач\n"
        report += "- Прогресс: \(Int(analysis.progress * 100))%\n"
        
        if analysis.overdueTasks > 0 {
            report += "- ⚠️ Просрочено задач: \(analysis.overdueTasks)\n"
        }
        
        if let completion = analysis.estimatedCompletion {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            report += "- Ожидаемое завершение: \(formatter.string(from: completion))\n"
        }
        
        report += "\n## Приоритетные задачи\n\n"
        for (index, priority) in analysis.priorities.enumerated() {
            report += "\(index + 1). \(priority)\n"
        }
        
        if !analysis.recommendations.isEmpty {
            report += "\n## Рекомендации\n\n"
            for recommendation in analysis.recommendations {
                report += "- \(recommendation)\n"
            }
        }
        
        return report
    }
}


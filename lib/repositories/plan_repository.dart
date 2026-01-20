import '../models/plan_result.dart';

abstract class PlanRepository {
  Future<void> savePlan(PlanResult plan, String name);
  
  Future<List<PlanResult>> getAllPlans();
  
  Future<PlanResult?> getLatestPlan();
  
  Future<void> deletePlan(String name);
  
  Future<void> deleteAllPlans();
}

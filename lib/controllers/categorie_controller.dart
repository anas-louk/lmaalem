import 'package:get/get.dart';
import '../../data/models/categorie_model.dart';
import '../../data/repositories/categorie_repository.dart';
import '../../core/helpers/snackbar_helper.dart';

/// Controller pour gérer les catégories (GetX)
class CategorieController extends GetxController {
  final CategorieRepository _categorieRepository = CategorieRepository();

  // Observable states
  final RxList<CategorieModel> categories = <CategorieModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<CategorieModel?> selectedCategorie = Rx<CategorieModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadAllCategories();
  }

  /// Charger toutes les catégories
  Future<void> loadAllCategories() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final categorieList = await _categorieRepository.getAllCategories();
      categories.assignAll(categorieList);
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Stream des catégories (temps réel)
  void streamCategories() {
    _categorieRepository.streamAllCategories().listen((categorieList) {
      categories.assignAll(categorieList);
    });
  }

  /// Créer une catégorie
  Future<bool> createCategorie(CategorieModel categorie) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _categorieRepository.createCategorie(categorie);
      await loadAllCategories();
      SnackbarHelper.showSuccess('category_created'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour une catégorie
  Future<bool> updateCategorie(CategorieModel categorie) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _categorieRepository.updateCategorie(categorie);
      await loadAllCategories();
      SnackbarHelper.showSuccess('category_updated'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Supprimer une catégorie
  Future<bool> deleteCategorie(String categorieId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _categorieRepository.deleteCategorie(categorieId);
      await loadAllCategories();
      SnackbarHelper.showSuccess('category_deleted'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sélectionner une catégorie
  void selectCategorie(CategorieModel categorie) {
    selectedCategorie.value = categorie;
  }

  /// Récupérer une catégorie par ID
  Future<CategorieModel?> getCategorieById(String categorieId) async {
    try {
      return await _categorieRepository.getCategorieById(categorieId);
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    }
  }
}


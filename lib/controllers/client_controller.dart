import 'package:get/get.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../core/helpers/snackbar_helper.dart';

/// Controller pour gérer les clients (GetX)
class ClientController extends GetxController {
  final ClientRepository _clientRepository = ClientRepository();

  // Observable states
  final Rx<ClientModel?> currentClient = Rx<ClientModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// Charger un client par ID
  Future<void> loadClient(String clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final client = await _clientRepository.getClientById(clientId);
      currentClient.value = client;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Créer un client
  Future<bool> createClient(ClientModel client) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _clientRepository.createClient(client);
      SnackbarHelper.showSuccess('client_created'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour un client
  Future<bool> updateClient(ClientModel client) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _clientRepository.updateClient(client);
      await loadClient(client.id);
      SnackbarHelper.showSuccess('client_updated'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}


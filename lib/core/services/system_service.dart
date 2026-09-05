import 'dart:io';

class SystemService {
  // Controlla se yay è installato nel sistema
  static Future<bool> isYayInstalled() async {
    try {
      final result = await Process.run('which', ['yay']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // Funzione per installare yay automaticamente in background (senza aprire il terminale utente)
  static Future<Stream<String>> installYay() async {
    // Qui useremo uno script in sequenza per clonare e compilare yay via makepkg
    // Eseguendo git clone https://aur.archlinux.org/yay-bin.git e makepkg -si --noconfirm
    // Restituendo l'output in tempo reale per la UI di caricamento.
    throw UnimplementedError();
  }
}
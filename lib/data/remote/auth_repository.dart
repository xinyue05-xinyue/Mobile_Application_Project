import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_role.dart';

class AuthRepository {
  const AuthRepository(this.client);

  final SupabaseClient client;

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String state,
    required DateTime dateOfBirth,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'state': state,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      },
    );
    if (response.user == null) {
      throw const AuthException('Unable to create the account.');
    }
    return response.session != null;
  }

  Future<UserRole> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('Login failed.');

    return getCurrentRole();
  }

  Future<UserRole> getCurrentRole() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('No active session.');

    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    return UserRole.fromDatabase(profile['role'] as String?);
  }

  Future<void> signOut() => client.auth.signOut();
}

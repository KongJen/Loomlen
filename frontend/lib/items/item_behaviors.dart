// ignore_for_file: non_constant_identifier_names

mixin Renamable {
  void rename(BuildContext, String id, String newName);
}

mixin Deletable {
  void delete(BuildContext, String id);
}

mixin Favoritable {
  void favorite(BuildContext, String id, bool isFavorite);
}

import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

abstract class PostRemoteDataSource {
  Stream<List<PostModel>> watchFeed({String? category});
  Future<void> createPost(PostModel post);
  Future<void> deletePost(String postId);
  Future<void> toggleLike({required String postId, required String uid});
  Future<bool> isLikedByUser({required String postId, required String uid});
  Stream<List<CommentModel>> watchComments(String postId);
  Future<void> addComment(CommentModel comment);
  Future<void> deleteComment(
      {required String postId, required String commentId});
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  final SupabaseDocumentStore store;

  PostRemoteDataSourceImpl(this.store);

  CollectionReference<Map<String, dynamic>> get _posts =>
      store.collection('posts');

  @override
  Stream<List<PostModel>> watchFeed({String? category}) {
    Query<Map<String, dynamic>> query = _posts
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(50);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  PostModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
              .toList(),
        );
  }

  @override
  Future<void> createPost(PostModel post) async {
    try {
      await _posts.add(post.toMap());
    } catch (e) {
      throw ServerException(message: 'تعذّر نشر المنشور: $e');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      // كانت هذه عملية حذف مباشرة (owner_id=auth.uid() OR dragon فقط) —
      // أي مشرف حقيقي بصلاحية chat.moderate كان يحصل على "نجاح" ظاهري بلا
      // أي حذف فعلي عند محاولة حذف منشور شخص آخر. moderator_delete_content
      // تعيد فرض القاعدة الصحيحة فعليًا: صاحب المحتوى، أو مشرف حقيقي، أو
      // المالك.
      await store.rpc('moderator_delete_content', params: {
        'p_collection': 'posts',
        'p_doc_id': postId,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر حذف المنشور: $e');
    }
  }

  @override
  Future<void> toggleLike({required String postId, required String uid}) async {
    try {
      final postRef = _posts.doc(postId);
      final likeRef = postRef.collection('likes').doc(uid);

      await store.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        if (likeSnap.exists) {
          tx.delete(likeRef);
          tx.update(postRef, {'likesCount': FieldValue.increment(-1)});
        } else {
          tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
          tx.update(postRef, {'likesCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث الإعجاب: $e');
    }
  }

  @override
  Future<bool> isLikedByUser(
      {required String postId, required String uid}) async {
    try {
      final doc = await _posts.doc(postId).collection('likes').doc(uid).get();
      return doc.exists;
    } catch (e) {
      throw ServerException(message: 'تعذّر التحقق من حالة الإعجاب: $e');
    }
  }

  @override
  Stream<List<CommentModel>> watchComments(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommentModel.fromMap(
                d.id, postId, Map<String, dynamic>.from(d.data())))
            .toList());
  }

  @override
  Future<void> addComment(CommentModel comment) async {
    try {
      final postRef = _posts.doc(comment.postId);
      final commentRef = postRef.collection('comments').doc();

      final batch = store.batch();
      batch.set(commentRef, comment.toMap());
      batch.update(postRef, {'commentsCount': FieldValue.increment(1)});
      await batch.commit();
    } catch (e) {
      throw ServerException(message: 'تعذّر إضافة التعليق: $e');
    }
  }

  @override
  Future<void> deleteComment(
      {required String postId, required String commentId}) async {
    try {
      // نفس إصلاح deletePost: تحذف التعليق وتُحدّث عدّاد المنشور معًا في
      // الدالة الخادمية نفسها، بعد التحقق الصحيح من الملكية أو صلاحية
      // الإشراف الحقيقية — لا حذفًا مباشرًا كان يفشل صمتًا لأي مشرف.
      await store.rpc('moderator_delete_content', params: {
        'p_collection': 'posts/$postId/comments',
        'p_doc_id': commentId,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر حذف التعليق: $e');
    }
  }
}

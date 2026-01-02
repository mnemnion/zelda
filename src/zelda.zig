//! Zelda: a Link to the List
//!
//! This library generates linked-list functions for a provided type, given
//! the name of the field or fields which are linkable.
//!

/// A CPU-friendly version of std.math.Order.  At some point I
/// expect Zig std to update to this version, at which point it
/// will become a synonym.  Your `zeldaOrderFn` can return either
/// this or the standard library's version; prefer this.
pub const Order = enum(i2) {
    lt = -1,
    eq = 0,
    gt = 1,
};

/// Long ago, in the beautiful kingdom of Hyrule surrounded by mountains and
/// forests...
///
/// legends told of an omnipotent and omniscient Golden Power that resided in a
/// hidden land. Many people aggressively sought to enter the hidden Golden Land...
///
/// But no one ever returned.
///
/// One day evil power began to flow from the Golden Land...
///
/// So the King commanded seven wise men to seal the gate to the Land of the
/// Golden Power. That seal should have remained for all time...
///
/// ...
///
/// ...But, when these events were obscured by the mists of time and became
/// legend...
///
/// A mysterious wizard known as Agahnim came to Hyrule to release the seal. He
/// eliminated the good King of Hyrule...
///
/// Through evil magic, he began to make descendants of the seven wise men vanish,
/// one after another. And the time of destiny for Princess Zelda is drawing near.
pub fn aLinkToThePast(T: type) type {
    return singlyLinkedListInner(T, .{});
}

/// There is a legend oft told in Hyrule Kingdom.
///
/// It is the legend of the Triforce, once kept within Hyrule itself.
///
/// Said to be a gift of the gods, the Triforce could grant a wish of all
/// those who touched it.
///
/// So of course, many wanted to get their hands on it.
///
/// Wars were fought for the Triforce.
///
/// The royal family summoned the Seven Sages, who sealed the Triforce
/// in the Sacred Realm.
///
/// But a thief of notorious repute broke into the Sacred Realm and claimed
/// the Triforce. With its power, he became the Demon King Ganon, who sought
/// to dominate all Hyrule.
///
/// But just as Ganon had the kingdom in his evil clutches... a legendary
/// hero answered the call of Hyrule's princess.
///
/// And this hero, wielding the Master Sword, took up a quest to challenge
/// Ganon's might. He joined with the descendants of the Seven Sages to seal
/// the Demon King in darkness. The Triforce was divided into three—its tempting
/// power out of any one person's reach.
///
/// One part stayed with the royal family, while another slipped into Ganon's
/// possession. Legend says that the third part found its home in the heart of
/// the hero eternal...
///
/// And while legends come to us from the distant past,
/// others have yet to be written...
pub fn aLinkBetweenWorlds(T: type) type {
    return doublyLinkedListInner(T, .{});
}

/// Returns a container type with methods for working with the Node type as
/// nodes in a doubly-linked list, using the field names `next_name` and
/// `prev_name`.  The container also contains a `List` type specialized to this
/// type of node.  This can be called repeatedly with new pairs of nodes, or
/// discrete order functions, it is advisable that each pair be disjoint but Zelda
/// will not stop you from doing otherwise.
pub fn doublyLinkedList(Node: type, comptime next_name: anytype, comptime prev_name: anytype, comptime m_orderFn: ?[]const u8) type {
    // String-ify potential enum literal:
    const next: []const u8 = if (@typeInfo(@TypeOf(next_name)) == .enum_literal)
        @tagName(next_name)
    else // If it coerces, it works:
        next_name;

    const prev: []const u8 = if (@typeInfo(@TypeOf(prev_name)) == .enum_literal)
        @tagName(prev_name)
    else // If it coerces, it works:
        prev_name;

    return doublyLinkedListInner(Node, .{ .next = next, .prev = prev, .orderFn = m_orderFn });
}

/// Provides a container with functions implementing singly-linkèd node
/// behavior for the type, and a List type for making use of such lists.
/// `next_name` must be a string or enum literal which represents a field of
/// type `?*Node` on Node itself.
///
/// It is legal to call this several times with different field names,
/// or different order function declarations, mix and match, your choice.
pub fn singlyLinkedList(Node: type, comptime next_name: anytype, comptime m_orderFn: ?[]const u8) type {
    const next: []const u8 = if (@typeInfo(@TypeOf(next_name)) == .enum_literal)
        @tagName(next_name)
    else // If it coerces, it works:
        next_name;

    return singlyLinkedListInner(Node, .{ .next = next, .orderFn = m_orderFn });
}

/// We need to do this whole elaborate thing so that the `Link` type is resolved before the
/// reference to the Link field is needed (@typeInfo):
/// https://github.com/ziglang/zig/issues/23362
/// https://github.com/ziglang/zig/issues/24636
fn singlyLinkedListInner(Node: type, info: anytype) type {
    const info_has_orderFn = @hasField(@TypeOf(info), "orderFn");
    const maybe_next: ?[]const u8 = if (@hasField(@TypeOf(info), "next")) info.next else null;
    const m_orderFn: ?[]const u8 = if (info_has_orderFn) info.orderFn else null;

    return struct { // Sema entering this definition resolves Link:
        const Link = @This(); // Making @typeInfo(Node) legal
        // Now we do a fun thing: find ourselves
        const link_field = link: {
            const t_info = @typeInfo(Node);
            if (t_info != .@"struct") @compileError("Link needs to be a struct");
            const t_fields = t_info.@"struct".fields;
            for (t_fields) |field| {
                if (field.type == Link) {
                    break :link field.name;
                }
            }
            @compileError(
                "The return value must be the type of a field" ++
                    " on the Link struct. It's zero width, don't worry!",
            );
        };

        const next = maybe_next orelse next_name: {
            const t_fields = @typeInfo(Node).@"struct".fields;
            for (t_fields) |field| {
                if (field.type == ?*Node) {
                    break :next_name field.name;
                }
            }
            @compileError(
                "There must be a linked list field on " ++ @typeName(Node) ++
                    " so we can do linked list things with it",
            );
        };

        pub const has_order = if (m_orderFn) |_| true else if (!info_has_orderFn) @hasDecl(Node, "zeldaOrderFn") else false;
        const order_name = if (m_orderFn) |orderFn| orderFn else if (has_order) "zeldaOrderFn" else "";

        pub const seek_limit =
            if (@hasDecl(Node, "ZELDA_SEEK_LIMIT"))
                Node.ZELDA_SEEK_LIMIT
            else if (@hasDecl(Node, "zelda_seek_limit"))
                Node.zelda_seek_limit
            else {};
        pub const has_limit = @TypeOf(seek_limit) != void and @TypeOf(seek_limit) != @TypeOf(null);

        inline fn base(link: *Link) *Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        inline fn cbase(link: *const Link) *const Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        /// Insert the argument node after the receiver node.
        pub fn insertAfter(link: *Link, new_node: *Node) void {
            const node = base(link);
            @field(new_node, next) = @field(node, next);
            @field(node, next) = new_node;
        }

        /// Remove the node after the one provided, returning it. Node will be
        /// linked to the node after that, if any.  If a node is returned, its
        /// next field will be null.
        pub fn removeNext(link: *Link) ?*Node {
            const node = base(link);
            const next_node = @field(node, next) orelse return null;
            @field(node, next) = @field(next_node, next);
            @field(next_node, next) = null;
            return next_node;
        }

        /// Swaps the `node`'s position with the Node at `next`.  If no such
        /// Node exists, then `node` is returned.  Otherwise, the now-previous
        /// node is returned, and a good thing too, because the list is no
        /// longer well-formed, which can be remedied by pointing whatever
        /// next-field this node came from at the return value.  Use with care.
        ///
        /// # Example (assuming "next" and "link")
        ///
        /// ```zig
        /// if (this_node.next) |next_node| {
        ///     this_node.next = next_node.link.swap();
        ///     assert((next_node.next == null and this_node.next == next_node) or
        ///         this_node.next.next = next_node);
        /// }
        /// ```
        ///
        /// You probably do not need this function.
        pub fn swap(link: *Link) *Node {
            const node = base(link);
            const next_node = @field(node, next) orelse return node;
            @field(node, next) = @field(next_node, next);
            @field(next_node, next) = node;
            return next_node;
        }

        /// Iterate over the singly-linked list from this node, until the final
        /// node is found.  O(n).  Prefer keeping a `List`.
        pub fn findLast(link: *Link) *Node {
            var it = base(link);
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (true) {
                if (has_limit) limit += 1;
                it = @field(it, next) orelse return it;
                if (has_limit) if (limit >= seek_limit) @panic("findLast exceeded seek limit");
            }
        }

        /// Iterate over each next node, returning the count of all nodes except
        /// the starting one.  O(n).  This is provided for compatibility with the
        /// standard library, which uses it for reasons I find obscure.  `len` is
        /// also available and does what you'd expect.
        pub fn countChildren(link: *const Link) usize {
            const node: *const Node = cbase(link);
            var count: usize = 0;
            var it: ?*const Node = @field(node, next);
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (it) |n| : (it = @field(n, next)) {
                if (has_limit) limit += 1;
                count += 1;
                if (has_limit) if (limit >= seek_limit) @panic("countChildren exceeded seek limit");
            }
            return count;
        }

        /// Answer the number of elements in the list in total, by iteration, in
        /// O(n).
        pub fn len(link: *const Link) usize {
            return 1 + link.countChildren();
        }

        /// Reverse the list starting from this node, returning the new head.  O(n).
        pub fn reverse(link: *Link) *Node {
            var m_current: ?*Node = base(link);
            const indirect: *?*Node = &m_current;
            reverseNode(indirect);
            return indirect.*.?;
        }

        /// Return the linked list to which this node belongs, in O(n).  It is
        /// generally preferable to maintain the list _as_ a list, rather than
        /// call this function.
        pub fn toList(link: *Link) List {
            const node = base(link);
            const last = link.findLast();
            return .{ .first = node, .last = last };
        }

        /// Answer whether the node is found in the list.  Provided
        /// for diagnostic and testing purposes.  Compares by pointer,
        /// not by value.
        pub fn belongsTo(link: *const Link, n2: *const Node) bool {
            var m_node: ?*const Node = cbase(link);
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (m_node) |node| : (m_node = @field(node, next)) {
                if (has_limit) limit += 1;
                if (node == n2) return true;
                if (has_limit) if (limit >= seek_limit) @panic("belongsTo exceeded seek limit");
            } else return false;
        }

        //| Ordered List Operations
        //|
        //| Ideally these would only exist in the namespace if an order function
        //| were provided.  I tried making them `void` unless there's an order
        //| function, but ZLS can't see through that kind of complex comptime
        //| wizardry, which is understandable if a little sad.
        //|
        //| So everyone is going to see these, but it will be a compile error to
        //| call them unless they can do something.  This will do for now.

        /// Sort a list after this node in ascending order, returning the
        /// smallest value.  This is a merge sort, taking constant space, and
        /// O(n log n) worst-case time.
        pub fn sortAscending(link: *Link) *Node {
            const node = base(link);
            return mergeSortFn(lessThan)(node);
        }

        /// Sort a list after this node in descending order, returning the
        /// largest value.  This is a merge sort, taking constant space, and
        /// O(n log n) worst-case time.
        pub fn sortDescending(link: *Link) *Node {
            const node = base(link);
            return mergeSortFn(greaterThan)(node);
        }

        /// If a sorted list is desired, it is inexpensive to capture the tailmost
        /// node as part of that process.  This function sorts the list after this
        /// node in ascending order, returning it as a `List`.
        pub fn toSortedListAscending(link: *Link) List {
            const node = base(link);
            // We're breaking the rules here: a list should never have one node
            // populated unless the other is.  But `sortAscending` doesn't check,
            // or make assumptions based on the invariant, so we get away with it.
            var the_list: List = .{ .first = node, .last = null };
            the_list.sortAscending();
            return the_list;
        }

        /// If a sorted list is desired, it is inexpensive to capture the tailmost
        /// node as part of that process.  This function sorts the list after this
        /// node in descending order, returning it as a `List`.
        pub fn toSortedListDescending(link: *Link) List {
            const node = base(link);
            var the_list: List = .{ .first = node, .last = null };
            the_list.sortDescending();
            return the_list;
        }

        /// Insert the argument node into the list, such that if already ordered
        /// ascending, the returned list will remain in ascending order.
        /// Strictly, it will be before the first node it sees which is equal to
        /// or greater than its value.  When list-building, it is often better
        /// to collect values and then call `sortAscending`, rather than use
        /// this to sort as you go.
        pub fn insertOrderedAscending(link: *Link, node: *Node) *Node {
            const head = base(link);
            return insertSortFn(lessThanEq)(head, node);
        }

        /// Insert the argument node into the list, such that if already ordered
        /// descending, the returned list will remain in descending order.
        /// Strictly, it will be before the first node it sees which is equal to
        /// or less than its value.  When list-building, it is often better to
        /// collect values and then call `sortDescending`, rather than use this
        /// to sort as you go.
        pub fn insertOrderedDescending(link: *Link, node: *Node) *Node {
            const head = base(link);
            return insertSortFn(greaterThanEq)(head, node);
        }

        /// Answer whether the node is the head of a list in ascending order.
        /// A useful diagnostic, assertion, and testing tool, but something
        /// production code should prefer to know by construction.
        pub fn isOrderedAscending(link: *Link) bool {
            const head = base(link);
            return inOrderFn(lessThanEq)(head);
        }

        /// Answer whether the node is the head of a list in descending order.
        /// A useful diagnostic, assertion, and testing tool, but something
        /// production code should prefer to know by construction.
        pub fn isOrderedDescending(link: *Link) bool {
            const head = base(link);
            return inOrderFn(greaterThanEq)(head);
        }

        inline fn orderGuard() void {
            if (!has_order)
                @compileError(
                    \\This mixin was not configured with an order function, and
                    \\cannot be sorted without one.  Zelda will find a public
                    \\declaration `zeldaOrderFn`, expecting the signature
                    \\
                    \\    fn(*const Node, *const Node) callconv(.@"inline") zelda.Order;
                    \\
                    \\Although the calling convention and specific enum are never checked, this
                    \\will allow the optimizer to generate the best code in the most cases.
                    \\
                    \\When configuring the mixin manually, provide the name of the declaration as
                    \\a string for the last argument, rather than `null`.
                );
        }

        inline fn lessThan(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) == .lt;
        }

        inline fn lessThanEq(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) != .gt;
        }

        inline fn greaterThan(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) == .gt;
        }

        inline fn greaterThanEq(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) != .lt;
        }

        fn insertSortFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node, *Node) *Node {
            return struct {
                pub fn insert(head: *Node, node: *Node) *Node {
                    orderGuard();
                    if (orderFn(node, head)) {
                        @field(node, next) = head;
                        return node;
                    }
                    var m_next = @field(head, next);
                    var last = head;
                    var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                    while (m_next) |next_node| {
                        if (has_limit) limit += 1;
                        if (orderFn(node, next_node)) {
                            @field(last, next) = node;
                            @field(node, next) = next_node;
                            return head;
                        }
                        last = next_node;
                        m_next = @field(next_node, next);
                        if (has_limit) if (limit >= seek_limit) @panic("insertSorted exceeded seek limit");
                    }
                    @field(last, next) = node;
                    return head;
                }
            }.insert;
        }

        fn inOrderFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) bool {
            return struct {
                pub fn inorder(head: *Node) bool {
                    orderGuard();
                    var this: *Node = head;
                    var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                    while (@field(this, next)) |next_node| {
                        if (has_limit) limit += 1;
                        if (orderFn(this, next_node)) {
                            this = next_node;
                        } else {
                            return false;
                        }
                        if (has_limit) if (limit >= seek_limit) @panic("inOrder exceeded seek limit");
                    } else {
                        return true;
                    }
                }
            }.inorder;
        }

        fn mergeSortFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) *Node {
            return struct {
                pub fn msort(n: *Node) *Node {
                    orderGuard();
                    var ep: ?*Node = null;
                    var set: [LISTSIZE]?*Node = .{null} ** LISTSIZE;
                    var m_list: ?*Node = n;
                    var first = true;
                    while (m_list) |list| {
                        ep = list;
                        // First, "gallop" past any already-sorted values,
                        // this brings the merge down to O(n) for an already-
                        // sorted list.
                        var m_gallop: ?*Node = list;
                        var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                        while (m_gallop) |gallop| {
                            if (has_limit) limit += 1;
                            if (@field(gallop, next)) |g_next| {
                                if (orderFn(gallop, g_next)) {
                                    m_gallop = g_next;
                                } else {
                                    m_list = g_next;
                                    @field(gallop, next) = null;
                                    break;
                                }
                            } else {
                                if (first) {
                                    // sorted!
                                    return n;
                                }
                                m_list = null;
                                break;
                            }
                            if (has_limit) if (limit >= seek_limit) @panic("merge exceeded seek limit");
                        }
                        first = false;
                        var i: usize = 0;
                        while (i < LISTSIZE - 1 and set[i] != null) : (i += 1) {
                            ep = merge(set[i], ep);
                            set[i] = null;
                        }
                        set[i] = merge(set[i], ep);
                    }
                    ep = null;
                    for (0..LISTSIZE) |i| {
                        if (set[i]) |tail| {
                            ep = merge(tail, ep);
                        }
                    }
                    return ep.?;
                }

                // Merge two linked lists, given the head. Either the first or the
                // second may be null: by construction, they will never both be
                // null, but it's harmless to our purposes to return a `?*T`, so
                // we wouldn't benefit from that fact and don't take advantage of it.
                fn merge(maybe_a: ?*Node, maybe_b: ?*Node) ?*Node {
                    if (maybe_a == null) return maybe_b;
                    if (maybe_b == null) return maybe_a;
                    var a: ?*Node = maybe_a;
                    var b: ?*Node = maybe_b;
                    const head: *Node = if (orderFn(a.?, b.?)) head: {
                        const h = a.?;
                        a = @field(h, next);
                        break :head h;
                    } else head: {
                        const h = b.?;
                        b = @field(h, next);
                        break :head h;
                    };
                    var ptr: *Node = head;
                    while (a != null and b != null) {
                        const a_ptr = a.?;
                        const b_ptr = b.?;
                        if (orderFn(a_ptr, b_ptr)) {
                            @field(ptr, next) = a_ptr;
                            ptr = a_ptr;
                            a = @field(a_ptr, next);
                        } else {
                            @field(ptr, next) = b_ptr;
                            ptr = b_ptr;
                            b = @field(b_ptr, next);
                        }
                    }
                    if (a) |a_ptr| {
                        @field(ptr, next) = a_ptr;
                    } else {
                        @field(ptr, next) = b;
                    }
                    return head;
                }
            }.msort;
        }

        /// Reverse the list starting from this node in-place.
        fn reverseNode(indirect: *?*Node) void {
            if (indirect.* == null) {
                return;
            }
            var current: *Node = indirect.*.?;
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (@field(current, next)) |the_next| {
                if (has_limit) limit += 1;
                @field(current, next) = @field(the_next, next);
                @field(the_next, next) = indirect.*;
                indirect.* = the_next;
                if (has_limit) if (limit >= seek_limit) @panic("findLast exceeded seek limit");
            }
        }

        //| Singly Linked List container type

        /// A singly-linked list of `*Node`, comprising the first and last
        /// elements of the list.  The API preserves the following properties:
        ///
        /// - If there is a first node, there will be a last.
        /// - The last node's next-field will be `null`.  This type is not suitable
        ///   for representing only the first part of a list, it can certainly
        ///   represent the tail of one, or indeed, the tail of several.
        ///
        /// The API also asserts these properties often, so if your code does any
        /// 'manual' manipulation of the list, take care to maintain them.
        pub const List = struct {
            first: ?*Node,
            last: ?*Node,

            pub const empty: List = .{ .first = null, .last = null };

            pub fn init(first: ?*Node) List {
                return .{ .first = first, .last = first };
            }

            /// Prepend `new_node` as the first link in the list.  It is not a
            /// requirement that the next-field be unset, but this will happen
            /// even if the list is empty.
            pub fn prepend(list: *List, new_node: *Node) void {
                @field(new_node, next) = list.first;
                if (list.last == null) {
                    assert(list.first == null);
                    list.last = new_node;
                }
                list.first = new_node;
            }

            /// Append a node to the end of the list. O(1). The node must
            /// have a `null` next field.
            pub fn append(list: *List, new_node: *Node) void {
                assert(@field(new_node, next) == null);
                if (list.last) |last| {
                    assert(@field(last, next) == null);
                    @field(last, next) = new_node;
                    list.last = new_node;
                }
                assert(list.first == null);
                list.last = new_node;
                list.first = new_node;
            }

            /// Find and remove `node` from the list.  This compares pointers,
            /// not values.  It is valid  to 'remove' a node which is not in
            /// the list, which does not make it a good idea.  If the node is
            /// found in the list, the 'next' field will be `null`, if it is
            /// not, the field will not change.
            pub fn remove(list: *List, node: *Node) void {
                if (list.first == node) {
                    list.first = @field(node, next);
                    if (list.last == node) {
                        assert(list.first == null);
                        list.last = list.first;
                    }
                    @field(node, next) = null;
                } else {
                    var current = list.first.?;
                    find: while (@field(current, next)) |next_node| {
                        if (next_node == node) {
                            @field(current, next) = @field(node, next);
                            @field(node, next) = null;
                            if (list.last == node) {
                                list.last = current;
                            }
                            break :find;
                        } else {
                            current = next_node;
                        }
                    }
                }
            }

            /// Find and remove `node` from the list.  This compares pointers,
            /// not values.  Asserts that `node` belongs to this list.  If the
            /// node is found in the list, the 'next' field will be `null`, if
            /// it is not found, the program will crash, or worse.  This might
            /// be faster to use than plain `remove`, or it might just be more
            /// dangerous to no actual benefit.  Benchmark or YOLO, it's your
            /// circus.
            pub fn removeUnchecked(list: *List, node: *Node) void {
                if (list.first == node) {
                    list.first = @field(node, next);
                    if (list.last == node) {
                        assert(list.first == null);
                        list.last = list.first;
                    }
                    @field(node, next) = null;
                } else {
                    var current = list.first.?;
                    while (true) {
                        const next_node = @field(current, next).?;
                        if (next_node == node) {
                            @field(current, next) = @field(node, next);
                            @field(node, next) = null;
                            if (list.last == node) {
                                list.last = current;
                            }
                            return;
                        }
                        current = next_node;
                    }
                }
            }

            /// Answer whether the node is found in the list.  Provided
            /// for diagnostic and testing purposes.
            pub fn belongsTo(list: *const List, node: *const Node) bool {
                if (list.last == node) return true;
                return @field(list.first, link_field).belongsTo(node);
            }

            /// Reverse the order of the nodes in the list, in-place, in
            /// O(n).  Legal to call on an empty list.
            pub fn reverse(list: *List) void {
                const temp = list.first;
                reverseNode(&list.first);
                list.last = temp;
            }

            /// Concatenate the argument list to the end of the receiver list in O(1).
            /// After this, the argument list will be empty.  It is legal for either
            /// list, or both, to begin empty.
            pub fn concat(list: *List, l2: *List) void {
                if (list.last) |last| {
                    @field(last, next) = l2.first;
                    list.last = l2.last;
                    l2.first = null;
                    l2.last = null;
                    return;
                }
                assert(list.first == null);
                list.first = l2.first;
                list.last = l2.last;
            }

            /// Split the list into two, after the Node provided, returning the
            /// new list.  The head of the new list will be `node.next`, the
            /// tail of this one will be `node`.  Caller is responsible for
            /// ensuring that `node` is a member of this list, nothing good will
            /// happen if that isn't true.  Corollary: the list must not be
            /// empty, and must in fact have no less than two members.  Asserts
            /// it is not the last member of the list.  O(1).
            pub fn splitAfter(list: *List, node: *Node) List {
                assert(list.last != null);
                assert(list.last != node);
                const new_first = @field(node, next);
                const new_last = list.last;
                list.last = node;
                @field(node, next) = null;
                return .{ .first = new_first, .last = new_last };
            }

            /// Remove and return the first node in the list, should one be
            /// present.  There is no `popLast`.
            pub fn popFirst(list: *List) ?*Node {
                const first = list.first orelse return null;
                list.first = @field(first, next);
                @field(first, next) = null;
                if (list.last == first) list.last = null;
                return first;
            }

            /// Iterate over all nodes, returning the count.
            ///
            /// This operation is O(n).  Consider tracking the length separately
            /// rather than computing it.
            pub fn len(list: *const List) usize {
                if (list.first) |n| {
                    return 1 + @field(n, link_field).countChildren();
                } else {
                    assert(list.last == null);
                    return 0;
                }
            }

            /// Answer if the list is empty.  This also asserts that the list is
            /// well-formed: either both fields are populated, or neither.
            pub fn isEmpty(list: *const List) bool {
                if (list.first) |_| {
                    assert(list.last != null);
                    return false;
                } else {
                    assert(list.last == null);
                    return true;
                }
            }

            //| Ordered Operations

            /// Insert the node into the list, such that if already ordered
            /// ascending, the returned list will remain in ascending order.
            /// Strictly, if it is greater than the last node's value, it will
            /// be after that, otherwise it will be before the first node it
            /// sees which is equal to or greater than its value.
            pub fn insertOrderedAscending(list: *List, node: *Node) void {
                if (greaterThan(node, list.last.?)) {
                    @field(list.last.?, next) = node;
                    @field(node, next) = null;
                } else {
                    list.first = @field(list.first.?, link_field).insertOrderedAscending(node);
                }
            }

            /// Insert the argument node into the list, such that if already
            /// ordered descending, the returned list will remain in descending
            /// order. Strictly, if it is less than the last node's value, it
            /// will be after that, otherwise it will be before the first node
            /// it sees which is equal to or less than its value.
            pub fn insertOrderedDescending(list: *List, node: *Node) *Node {
                if (lessThan(node, list.last.?)) {
                    @field(list.last.?, next) = node;
                    @field(node, next) = null;
                } else {
                    list.first = @field(list.first.?, link_field).insertOrderedDescending(node);
                }
            }

            /// Answer if the list is sorted in ascending order.  Perhaps surprisingly,
            /// an empty list will answer `true`.
            pub fn isOrderedAscending(list: *List) bool {
                if (list.first == null) return true;
                return @field(list.first.?, link_field).isOrderedAscending();
            }

            /// Answer if the list is sorted in descending order.  Perhaps surprisingly,
            /// an empty list will answer `true`.
            pub fn isOrderedDescending(list: *List) bool {
                if (list.first == null) return true;
                return @field(list.first.?, link_field).isOrderedDescending();
            }

            /// Sort the list in-place into ascending order.
            pub fn sortAscending(list: *List) void {
                if (list.first == null or list.first == list.last) return;
                list.first, list.last = mergeSortListFn(lessThan)(list.first.?);
            }

            /// Sort the list in-place into descending order.
            pub fn sortDescending(list: *List) void {
                if (list.first == null or list.first == list.last) return;
                list.first, list.last = mergeSortListFn(greaterThan)(list.first.?);
            }

            fn mergeSortListFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) struct { *Node, *Node } {
                return struct {
                    pub fn msort(n: *Node) struct { *Node, *Node } {
                        orderGuard();
                        var ep: ?*Node = null;
                        var set: [LISTSIZE]?*Node = .{null} ** LISTSIZE;
                        var m_list: ?*Node = n;
                        var first = true;
                        while (m_list) |list| {
                            ep = list;
                            // First, "gallop" past any already-sorted values,
                            // this brings the merge down to O(n) for an already-
                            // sorted list.
                            var m_gallop: ?*Node = list;
                            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                            while (m_gallop) |gallop| {
                                if (has_limit) limit += 1;
                                if (@field(gallop, next)) |g_next| {
                                    if (orderFn(gallop, g_next)) {
                                        m_gallop = g_next;
                                    } else {
                                        m_list = g_next;
                                        @field(gallop, next) = null;
                                        break;
                                    }
                                } else {
                                    if (first) {
                                        // sorted!
                                        return .{ n, gallop };
                                    }
                                    m_list = null;
                                    break;
                                }
                                if (has_limit) if (limit >= seek_limit) @panic("mergeSortList exceeded seek limit");
                            }
                            first = false;
                            var i: usize = 0;
                            while (i < LISTSIZE - 1 and set[i] != null) : (i += 1) {
                                ep = merge(set[i], ep);
                                set[i] = null;
                            }
                            set[i] = merge(set[i], ep);
                        }
                        ep = null;
                        // Compress the fragments.  We could just count them but
                        // it takes the same amount of time.
                        var off: usize = 0;
                        for (0..LISTSIZE) |i| {
                            if (set[i]) |_| {
                                set[i - off] = set[i];
                            } else {
                                off += 1;
                            }
                        } // The amount remaining is just:
                        var amt = LISTSIZE - off;
                        assert(amt > 0);
                        var i: usize = 0;
                        while (amt > 1) {
                            ep = merge(set[i].?, ep);
                            i += 1;
                            amt -= 1;
                        }
                        // Ep might be null here, if we only have one list,
                        // but that's ok:
                        return mergeFinal(set[i], ep);
                    }

                    // Merge two linked lists, given the head. Either the first or the
                    // second may be null: by construction, they will never both be
                    // null, but it's harmless to our purposes to return a `?*T`, so
                    // we wouldn't benefit from that fact and don't take advantage of it.
                    fn merge(maybe_a: ?*Node, maybe_b: ?*Node) ?*Node {
                        if (maybe_a == null) return maybe_b;
                        if (maybe_b == null) return maybe_a;
                        var a: ?*Node = maybe_a;
                        var b: ?*Node = maybe_b;
                        const head: *Node = if (orderFn(a.?, b.?)) head: {
                            const h = a.?;
                            a = @field(h, next);
                            break :head h;
                        } else head: {
                            const h = b.?;
                            b = @field(h, next);
                            break :head h;
                        };
                        var ptr: *Node = head;
                        while (a != null and b != null) {
                            const a_ptr = a.?;
                            const b_ptr = b.?;
                            if (orderFn(a_ptr, b_ptr)) {
                                @field(ptr, next) = a_ptr;
                                ptr = a_ptr;
                                a = @field(a_ptr, next);
                            } else {
                                @field(ptr, next) = b_ptr;
                                ptr = b_ptr;
                                b = @field(b_ptr, next);
                            }
                        }
                        if (a) |a_ptr| {
                            @field(ptr, next) = a_ptr;
                        } else {
                            @field(ptr, next) = b;
                        }
                        return head;
                    }

                    // Final merge: "a" is never null, but we need a variable anyway, so it's
                    // convenient to cast here.  This time we retain or find the tail and
                    // return it as well.
                    fn mergeFinal(maybe_a: ?*Node, maybe_b: ?*Node) struct { *Node, *Node } {
                        assert(maybe_a != null);
                        if (maybe_b == null) {
                            return .{ maybe_a.?, @field(maybe_a.?, link_field).findLast() };
                        }
                        var a: ?*Node = maybe_a;
                        var b: ?*Node = maybe_b;
                        const head: *Node = if (orderFn(a.?, b.?)) head: {
                            const h = a.?;
                            a = @field(h, next);
                            break :head h;
                        } else head: {
                            const h = b.?;
                            b = @field(h, next);
                            break :head h;
                        };
                        var ptr: *Node = head;
                        while (a != null and b != null) {
                            const a_ptr = a.?;
                            const b_ptr = b.?;
                            if (orderFn(a_ptr, b_ptr)) {
                                @field(ptr, next) = a_ptr;
                                ptr = a_ptr;
                                a = @field(a_ptr, next);
                            } else {
                                @field(ptr, next) = b_ptr;
                                ptr = b_ptr;
                                b = @field(b_ptr, next);
                            }
                        }
                        if (a) |a_ptr| {
                            @field(ptr, next) = a_ptr;
                            return .{ head, @field(a_ptr, link_field).findLast() };
                        } else if (b) |b_ptr| {
                            @field(ptr, next) = b_ptr;
                            return .{ head, @field(b_ptr, link_field).findLast() };
                        } else {
                            // Unreachable but if it weren't we'd do this:
                            return .{ head, ptr }; // So why not ¯\_(ツ)_/¯
                            //
                        }
                    }
                }.msort;
            }
        };
    };
}

/// The possible positions of a doubly-linked node within a
/// list of same.
pub const DoubleLinkedListPosition = enum {
    first,
    last,
    middle,
    solo,
};

fn doublyLinkedListInner(Node: type, info: anytype) type {
    const info_has_orderFn = @hasField(@TypeOf(info), "orderFn");
    const maybe_next: ?[]const u8 = if (@hasField(@TypeOf(info), "next")) info.next else null;
    const maybe_prev: ?[]const u8 = if (@hasField(@TypeOf(info), "prev")) info.prev else null;
    const m_orderFn: ?[]const u8 = if (info_has_orderFn) info.orderFn else null;

    return struct {
        const Link = @This(); // Making @typeInfo(Node) legal
        // Now we do a fun thing: find ourselves
        const link_field = link: {
            const t_info = @typeInfo(Node);
            if (t_info != .@"struct") @compileError("Link needs to be a struct");
            const t_fields = t_info.@"struct".fields;
            for (t_fields) |field| {
                if (field.type == Link) {
                    break :link field.name;
                }
            }
            @compileError(
                "The return value must be the type of a field" ++
                    " on the Link struct. It's zero width, don't worry!",
            );
        };

        const the_names: struct { []const u8, []const u8 } = if (maybe_next) |the_next| //
            .{ the_next, maybe_prev.? } //
        else next_names: {
            var find_names: struct { []const u8, []const u8 } = undefined;
            const t_fields = @typeInfo(Node).@"struct".fields;
            var first = true;
            for (t_fields) |field| {
                if (field.type == ?*Node) {
                    if (first) {
                        first = false;
                        find_names.@"0" = field.name;
                    } else {
                        find_names.@"1" = field.name;
                        break :next_names find_names;
                    }
                }
            }
            @compileError(
                "There must be two linked list fields on " ++ @typeName(Node) ++
                    if (!first) " not just one," else "" ++
                        " so we can do linked list things with it",
            );
        };

        const next = the_names.@"0";
        const prev = the_names.@"1";

        const has_order = if (m_orderFn) |_| true else if (!info_has_orderFn) @hasDecl(Node, "zeldaOrderFn") else false;
        const order_name = if (m_orderFn) |orderFn| orderFn else if (has_order) "zeldaOrderFn" else "";

        pub const seek_limit =
            if (@hasDecl(Node, "ZELDA_SEEK_LIMIT"))
                Node.ZELDA_SEEK_LIMIT
            else if (@hasDecl(Node, "zelda_seek_limit"))
                Node.zelda_seek_limit
            else {};
        pub const has_limit = @TypeOf(seek_limit) != void and @TypeOf(seek_limit) != @TypeOf(null);

        inline fn base(link: *Link) *Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        inline fn cbase(link: *const Link) *const Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        /// Return the node as a List, heedless of where in that list it happens to
        /// be.  O(n).
        ///
        /// This function is first for a reason.  Despite the quite rich
        /// collection of list-manipulations available for direct list-doings,
        /// a doubly-linked list is far more comfortable to operate _as_ a
        /// list, not simply a node with stuff hanging off it in one or both
        /// directions.
        pub fn toList(link: *Link) List {
            return .{ .first = link.findFirst(), .last = link.findLast() };
        }

        /// Insert the argument node forward of the receiver node.  The calling node
        /// is assumed to be on list, the argument is not.  This can concatenate two
        /// lists, if the receiver is a `.last` and the argument a `.first`.  It
        /// can also, as a consequence, create cycles.  If `new_node` is on another
        /// list, that can leak memory: this function assumes you know what you're
        /// doing.
        ///
        /// # Example use (assuming .link, .next, .prev)
        ///
        /// ```zig
        /// a.link.emplaceForward(b);
        /// assert(a.next == b);
        /// assert(b.prev == a);
        /// ```
        pub fn emplaceForward(link: *Link, new_node: *Node) void {
            const node = base(link);
            @field(new_node, prev) = node;
            if (@field(node, next)) |next_node| {
                // Intermediate node.
                @field(new_node, next) = next_node;
                @field(next_node, prev) = new_node;
            } else {
                // Last element of the list.
                // Either we allow cycles (no null set),
                // or we unexpectedly sever the list (null set),
                // so we do the former.
            }
            @field(node, next) = new_node;
        }

        /// Insert the argument node backward of the receiver node.  The
        /// calling node is assumed to be on list, the argument is not.  This
        /// can concatenate two lists, if the receiver is a `.first` and
        /// the argument a `.last`.  It can also, as a consequence, create
        /// cycles. If `new_node` is on another list, that can leak memory: this
        /// function assumes you know what you're doing.
        ///
        /// # Example use (assuming .link, .next, .prev)
        ///
        /// ```zig
        /// a.link.emplaceBackward(b);
        /// assert(a.prev == b);
        /// assert(b.next == a);
        /// ```
        pub fn emplaceBackward(link: *Link, new_node: *Node) void {
            const node = base(link);
            @field(new_node, next) = node;
            if (@field(node, prev)) |prev_node| {
                // Intermediate node.
                @field(new_node, prev) = prev_node;
                @field(prev_node, next) = new_node;
            } else {
                // First element of the list.
            }
            @field(node, prev) = new_node;
        }

        /// Return the position of the node within some unspecified list.
        pub fn positionInList(link: *Link) DoubleLinkedListPosition {
            const node = base(link);
            if (@field(node, prev)) |_| {
                if (@field(node, next)) |_| {
                    return .middle;
                } else {
                    return .last;
                }
            } else if (@field(node, next)) |_| {
                return .first;
            } else {
                return .solo;
            }
        }

        /// Remove the receiver node from the linked list.  Use carefully!  This
        /// can strand memory and lead to a leak.  Prefer to use the function
        /// `remove` on the `List` type.  If `node.positionInList() == .middle`,
        /// this will not strand either end of a properly-constituted list.
        /// See also `removeSelfReturnEnd`.
        pub fn removeSelfFromList(link: *Link) void {
            const node = base(link);
            if (@field(node, prev)) |prev_node| {
                if (@field(node, next)) |next_node| {
                    @field(prev_node, next) = next_node;
                    @field(next_node, prev) = prev_node;
                } else {
                    @field(prev_node, next) = null;
                }
            } else if (@field(node, next)) |next_node| {
                @field(next_node, prev) = null;
            } else return;
            @field(node, prev) = null;
            @field(node, next) = null;
        }

        /// Remove the receiver node from the linked list.  If it has two
        /// neighbors, or none, this returns `null`.  If it has one neighbor,
        /// the neighbor is returned.  Code will generally know which end is
        /// expected, which is in any case easy to check with `positionInList`.
        pub fn removeSelfReturnEnd(link: *Link) ?*Node {
            const node = base(link);
            if (@field(node, prev) == null) {
                // .solo or .first:
                defer link.removeSelfFromList();
                return @field(node, next);
            } else if (@field(node, next) == null) {
                // .last:
                defer link.removeSelfFromList();
                return @field(node, prev);
            } else {
                link.removeSelfFromList();
            }
        }

        /// Unlink from the forward structure, if any.  Returns the unlinked
        /// struct, or null.
        pub fn unlinkForward(link: *Link) ?*Node {
            const node = base(link);
            const this_next = @field(node, next) orelse return null;
            @field(this_next, prev) = null;
            @field(node, next) = null;
            return this_next;
        }

        /// Unlink from the backward structure, if any.  Returns the unlinked
        /// struct, or null.
        pub fn unlinkBackward(link: *Link) ?*Node {
            const node = base(link);
            const this_prev = @field(node, prev) orelse return null;
            @field(this_prev, next) = null;
            @field(node, prev) = null;
            return this_prev;
        }

        /// Swaps this node's position with the position of `node.next`.  If it
        /// is `null`, nothing happens.  This can invalidate the last node in a
        /// `List`, this condition can be detected (given otherwise proper use)
        /// if `node.next` is `null` after the call.
        pub fn swapForward(link: *Link) void {
            // ABCD -- ACBD.  node is B
            const nodeB = base(link);
            const nodeC: *Node = @field(nodeB, next) orelse return;
            const nodeA: ?*Node = @field(nodeB, prev);
            const nodeD: ?*Node = @field(nodeC, next);

            // B <-> D
            if (nodeD) |D| @field(D, prev) = nodeB;
            @field(nodeB, next) = nodeD;

            // C <-> B
            @field(nodeB, prev) = nodeC;
            @field(nodeC, next) = nodeB;

            // A <-> C
            @field(nodeC, prev) = nodeA;
            if (nodeA) |A| @field(A, next) = nodeC;
        }

        /// Swaps this node's position with the position of `node.prev`.  If it
        /// is `null`, nothing happens.  This can invalidate the first node in a
        /// `List`, this condition can be detected (given otherwise proper use)
        /// if `node.prev` is `null` after the call.
        pub fn swapBackward(link: *Link) void {
            // ABCD -- ACBD.  node is C
            const nodeC = base(link);
            const nodeB: *Node = @field(nodeC, prev) orelse return;
            const nodeD: ?*Node = @field(nodeC, next);
            const nodeA: ?*Node = @field(nodeB, prev);

            // A <-> C
            @field(nodeC, prev) = nodeA;
            if (nodeA) |A| @field(A, next) = nodeC;

            // C <-> B
            @field(nodeC, next) = nodeB;
            @field(nodeB, prev) = nodeC;

            // B <-> D
            @field(nodeB, next) = nodeD;
            if (nodeD) |D| @field(D, prev) = nodeB;
        }

        /// Splices the list in the `next` direction of the receiver.  The list
        /// is not cleared and will be in an invalid state.  It is checked illegal
        /// behavior for `list` to be empty.  Prefer to use `spliceForwardOf` on
        /// the list containing the node.
        pub fn spliceForward(link: *Link, list: *List) void {
            const node = base(link);
            const node_next = @field(node, link_field).unlinkForward();

            @field(node, next) = list.first;
            @field(list.first.?, prev) = node;

            @field(list.last.?, next) = node_next;
            if (node_next) |nn| @field(nn, prev) = list.last;
        }

        /// Slices the list in the `prev` direction of the receiver.  The list is
        /// not cleared and will be in an invalid state.  It is checked illegal
        /// behavior for `list` to be empty.  Prefer to use `spliceBackwardOf` on
        /// the list containing the node.
        pub fn spliceBackward(link: *Link, list: *List) void {
            const node = base(link);
            const node_prev = @field(node, link_field).unlinkBackward();
            @field(node, prev) = list.last;
            @field(list.last.?, next) = node;

            @field(list.first.?, prev) = node_prev;
            if (node_prev) |np| @field(np, next) = list.first;
        }

        /// This traverses the list forward, setting all backward links to point
        /// to their proper target.  It can be useful to pretend a doubly-linked
        /// list is singly-linked when chopping and splicing, this function
        /// restores the invariant.  As a convenience, this returns the _last_
        /// node in the forward direction.  You already have the first one.
        pub fn fixBackLinks(link: *Link) *Node {
            const node = base(link);
            var m_node: ?*Node = node;
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (@field(m_node, next)) |next_node| {
                if (has_limit) limit += 1;
                @field(next_node, prev) = m_node;
                m_node = next_node;
                if (has_limit) if (limit >= seek_limit) @panic("fixBackLinks exceeded seek limit");
            }
            return m_node.?;
        }

        /// This traverses the list backward, setting all forward links to
        /// point to their proper target.  This is the exotic companion to
        /// `fixBacklinks`, expected to be rarely used in practice.  Note that
        /// this returns the _last_ node in the _backward_ direction, since you
        /// already have the first one.
        pub fn fixForwardLinks(link: *Link) *Node {
            const node = base(link);
            var m_node: ?*Node = node;
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (@field(m_node, prev)) |prev_node| {
                if (has_limit) limit += 1;
                @field(prev_node, next) = m_node;
                m_node = prev_node;
                if (has_limit) if (limit >= seek_limit) @panic("fixForwardLinks exceeded seek limit");
            }
            return m_node.?;
        }

        /// Traverse forward until the final node is reached, then return it.
        /// This may be the same node as the receiver.  Backward links are
        /// ignored.
        pub fn findLast(link: *Link) *Node {
            const node = base(link);
            var m_node: ?*Node = node;
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (@field(m_node.?, next)) |next_node| {
                if (has_limit) limit += 1;
                m_node = next_node;
                if (has_limit) if (limit >= seek_limit) @panic("findEndForward exceeded seek limit");
            }
            return m_node.?;
        }

        /// Traverse backward until the final node is reached, then return it.
        /// This may be the same node as the receiver.  Forward links are
        /// ignored.
        pub fn findFirst(link: *Link) *Node {
            const node = base(link);
            var m_node: ?*Node = node;
            var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
            while (@field(m_node.?, prev)) |next_node| {
                if (has_limit) limit += 1;
                m_node = next_node;
                if (has_limit) if (limit >= seek_limit) @panic("findEndBackward exceeded seek limit");
            }
            return m_node.?;
        }

        //| Queries and diagnostics

        //| NOTE: The following four functions deliberately do not include the
        //| iteration limit.  Two reasons: they contain logic which will break
        //| out of cycles, and they are strictly diagnostic, having no place in
        //| production code.  If they had the iteration limit, they would answer
        //| a second question not specified by the name, which is bad form.

        /// Answers whether the node is in a well-formed double linked
        /// list when following the 'next' pointers.  Perhaps surprisingly,
        /// this answers `true` if `node.next` is `null`.  A `false` answer
        /// means there's a problem with your list.  This is a diagnostic
        /// tool.  A cyclic list is not considered "well-formed" for the
        /// purposes of this function.
        pub fn inDoubleLinkedListForward(link: *const Link) bool {
            const node = cbase(link);
            var this_node = node;
            var m_next = @field(this_node, next);
            while (m_next) |next_node| {
                if (@field(next_node, prev) != this_node) return false;
                if (node == next_node) return false;
                this_node = next_node;
                m_next = @field(next_node, next);
            }
            return true;
        }

        /// Answers whether the node is in a well-formed double linked
        /// list when following the 'prev' pointers.  Perhaps surprisingly,
        /// this answers `true` if `node.prev` is `null`.  A `false` answer
        /// means there's a problem with your list.  This is a diagnostic
        /// tool.  A cyclic list is not considered "well-formed" for the
        /// purposes of this function..
        pub fn inDoubleLinkedListBackward(link: *const Link) bool {
            const node = cbase(link);
            var this_node = node;
            var m_prev = @field(this_node, prev);
            while (m_prev) |prev_node| {
                if (@field(prev_node, next) != this_node) return false;
                if (node == prev_node) return false;
                this_node = prev_node;
                m_prev = @field(prev_node, prev);
            }
            return true;
        }

        /// Answers whether the node is in a cycle, or whether it enters
        /// one in the forward direction.  Uses Floyd-Knuth Tortoise and
        /// Hare Algorithm.  Will detect proper loops, where each double
        /// link is valid, but does not validate back links.  A diagnostic
        /// tool, for when your program hangs and you need to know why.
        pub fn inCycleForward(link: *Link) bool {
            const node = base(link);
            var tortoise: *Node = node;
            var hare = @field(node, next);
            while (@field(tortoise, next)) |next_tortoise| {
                if (hare == null) return false;
                const hare_next = @field(hare.?, next);
                if (hare_next == tortoise) return true;
                if (hare_next) |next_hare| {
                    hare = @field(next_hare, next);
                    if (hare) |next_next_hare| {
                        if (next_next_hare == tortoise) return true;
                    } else return false;
                } else {
                    return false;
                }
                tortoise = next_tortoise;
            }
            // Node is null forward, that's a false:
            return false;
        }

        /// Answers whether the node is in a cycle, or whether it enters
        /// one in the backward direction.  Uses Floyd-Knuth Tortoise and
        /// Hare Algorithm.  Will detect proper loops, where each double
        /// link is valid, but does not validate forward links.  A
        /// diagnostic tool, for when your program hangs and you need to
        /// know why.
        pub fn inCycleBackward(link: *Link) bool {
            const node = base(link);
            var tortoise: *Node = node;
            var hare = @field(node, prev);
            while (@field(tortoise, prev)) |prev_tortoise| {
                if (hare == null) return false;
                const hare_prev = @field(hare.?, prev);
                if (hare_prev == tortoise) return true;
                if (hare_prev) |prev_hare| {
                    hare = @field(prev_hare, prev);
                    if (hare) |prev_prev_hare| {
                        if (prev_prev_hare == tortoise) return true;
                    } else return false;
                } else {
                    return false;
                }
                tortoise = prev_tortoise;
            }
            // Node is null backward, that's a false:
            return false;
        }

        //| Ordering functions
        //|
        //| For doubly-linked lists it is utterly pointless to have one,
        //| have it be sorted, and not retain the tail.  So the nodes
        //| have only two functions which sort and return a List, the
        //| remainder of the (numerous!) operartions made available are
        //| found on List itself.

        /// Sort (forward) in ascending order.  Asserts that the backward
        /// link is `null`.  Because the merge sort rebuilds the backlinks at
        /// the end of a sort, it is free to include the tail, so there is no
        /// `*Node`-returning equivalent.
        pub fn sortAscending(link: *Link) List {
            const node = base(link);
            assert(@field(node, prev) == null);
            var list: List = undefined;
            list.first, list.last = mergeSortFn(lessThan)(node);
            return list;
        }

        /// Sort (forward) in ascending order.  Asserts that the backward
        /// link is `null`.  Because the merge sort rebuilds the backlinks at
        /// the end of a sort, it is free to include the tail, so there is no
        /// `*Node`-returning equivalent.
        pub fn sortDescending(link: *Link) List {
            const node = base(link);
            assert(@field(node, prev) == null);
            var list: List = undefined;
            list.first, list.last = mergeSortFn(greaterThan)(node);
            return list;
        }

        //| Matching

        /// The match interface.  Expects a function which answers whether
        /// any node is a match, and a context pointer which is the first
        /// argument to that function.  Provides finding, filter, and a
        /// find iterator.
        ///
        /// As a tip: the context pointer can be data, not just an address, for
        /// this application that can be rather useful: an enum, a threshold,
        /// many ranges.
        pub const Matcher = struct {
            ctx: *anyopaque,
            match: *const fn (*anyopaque, *Node) bool,

            /// Find the first match, returning it if found.  The node is not
            /// removed from the list.
            pub fn findFirst(m: *Matcher, list: *List) ?*Node {
                var m_node: ?*Node = list.first;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| : (m_node = @field(node, next)) {
                    if (has_limit) limit += 1;
                    if (m.match(m.ctx, node)) return node;
                    if (has_limit) if (limit >= seek_limit) @panic("findFirst exceeded seek limit");
                } else return null;
            }

            /// Find the last match, returning it if found.  The node is not
            /// removed from the list.
            pub fn findLast(m: *Matcher, list: *List) ?*Node {
                var m_node: ?*Node = list.last;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| : (m_node = @field(node, prev)) {
                    if (has_limit) limit += 1;
                    if (m.match(m.ctx, node)) return node;
                    if (has_limit) if (limit >= seek_limit) @panic("findLast exceeded seek limit");
                } else return null;
            }

            /// Find the first match, remove it from the list if found, and
            /// return it.
            pub fn findRemoveFirst(m: *Matcher, list: *List) ?*Node {
                var m_node: ?*Node = list.first;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| : (m_node = @field(node, next)) {
                    if (has_limit) limit += 1;
                    if (m.match(m.ctx, node)) {
                        return list.popNode(node);
                    }
                    if (has_limit) if (limit >= seek_limit) @panic("findRemoveFirst exceeded seek limit");
                } else return null;
            }

            /// Find the last match, remove it from the list if found, and
            /// return it.
            pub fn findRemoveLast(m: *Matcher, list: *List) ?*Node {
                var m_node: ?*Node = list.last;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| : (m_node = @field(node, prev)) {
                    if (has_limit) limit += 1;
                    if (m.match(m.ctx, node)) {
                        return list.popNode(node);
                    }
                    if (has_limit) if (limit >= seek_limit) @panic("findRemoveLast exceeded seek limit");
                } else return null;
            }

            /// Find the first 'run': the first match and every match which directly
            /// follows it.  Return the head and tail of the run, which may be the
            /// same node.  Note that this is not a list!  It may be removed with
            /// `list.extractRange`, if desired.
            pub fn findFirstRun(m: *Matcher, list: *List) ?struct { *Node, *Node } {
                var m_node: ?*Node = list.first;
                var m_first: ?*Node = null;
                var m_last: ?*Node = null;
                while (m_node) |node| : (m_node = @field(node, next)) {
                    if (m.match(m.ctx, node)) {
                        if (m_first) |_| {
                            m_last = node;
                        } else {
                            m_first = node;
                        }
                    } else if (m_first) |first| {
                        return .{ first, m_last orelse first };
                    }
                } else return null;
            }

            /// Find the last 'run': the last match and every match which
            /// directly precedes it.  Return the head and tail of the run,
            /// which may be the same node.  Note that this is not a list!  It
            /// will, however, be in 'list order', not the order in which they
            /// are found.  It may be removed with `list.extractRange`, if
            /// desired; this is one of the reasons why the head (last found) is
            /// the first element of the struct.
            pub fn findLastRun(m: *Matcher, list: *List) ?struct { *Node, *Node } {
                var m_node: ?*Node = list.last;
                var m_first: ?*Node = null;
                var m_last: ?*Node = null;
                while (m_node) |node| : (m_node = @field(node, prev)) {
                    if (m.match(m.ctx, node)) {
                        if (m_first) |_| {
                            m_last = node;
                        } else {
                            m_first = node;
                        }
                    } else if (m_first) |first| {
                        return .{ m_last orelse first, first };
                    }
                } else return null;
            }

            /// Find the next (forward) match after the provided Node.
            /// There is no remove variant of this function.
            pub fn findNext(m: *Matcher, node: *Node) ?*Node {
                // Cheating is ok when you make the rules.
                var list: List = .empty;
                list.first = @field(node, next);
                return m.findFirst(list);
            }

            /// Find the previous (backward) match before the provided Node.
            /// There is no remove variant of this function.
            pub fn findPrev(m: *Matcher, node: *Node) ?*Node {
                var list: List = .empty;
                list.last = @field(node, prev);
                return m.findLast(list);
            }

            /// Find the next (forward) run after the provided Node.
            /// See `findNextRun` for details.  Iterative use should pass
            /// in `run.@"1"`.
            pub fn findNextRun(m: *Matcher, node: *Node) ?struct { *Node, *Node } {
                // Cheating is ok when you make the rules.
                var list: List = .empty;
                list.first = @field(node, next);
                return m.findFirstRun(list);
            }

            /// Find the previous (backward) run before the provided Node.
            /// See `findPrevRun` for details.  Iterative use should pass
            /// in `run.@"0"`.
            pub fn findPrevRun(m: *Matcher, node: *Node) ?struct { *Node, *Node } {
                var list: List = .empty;
                list.last = @field(node, prev);
                return m.findLastRun(list);
            }

            /// Filter the list forward.  All matches are removed and emplaced
            /// on a new list, which is returned.  Either list may be empty
            /// after this operation completes.
            pub fn filterForward(m: *Matcher, list: *List) List {
                var flist: List = .empty;
                var m_node: ?*Node = list.first;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| {
                    if (has_limit) limit += 1;
                    const m_next = @field(node, next);
                    if (m.match(m.ctx, node)) {
                        flist.append(list.popNode(node));
                    }
                    m_node = m_next;
                    if (has_limit) if (limit >= seek_limit) @panic("filterForward exceeded seek limit");
                }
                return flist;
            }

            /// Filter the list backward.  All matches are removed and emplaced
            /// on a new list, which is returned.  Any matches will be in the
            /// opposite order from their order on the original list.  Either
            /// list may be empty after this operation completes.
            pub fn filterBackward(m: *Matcher, list: *List) List {
                var flist: List = .empty;
                var m_node: ?*Node = list.last;
                var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                while (m_node) |node| {
                    if (has_limit) limit += 1;
                    const m_next = @field(node, prev);
                    if (m.match(m.ctx, node)) {
                        flist.append(list.popNode(node));
                    }
                    m_node = m_next;
                    if (has_limit) if (limit >= seek_limit) @panic("filterBackward exceeded seek limit");
                }
                return flist;
            }

            /// Return a finder, which will iterate over the list in either
            /// direction, returning what it finds.  Mutating the list directly
            /// while using a Finder can have confusing results, so let the
            /// Finder do any popping you might need.  Important note: the
            /// Finder _will not_ return results until an end is specified with
            /// `finder.fromFirst` or `finder.fromLast`.  This can be confused
            /// with no matches, feel free to use the convenience functions
            /// `forwardFinder` and `backwardFinder`.
            pub fn finder(m: *Matcher, list: *List) Finder {
                return .{ .m = m, .list = list };
            }

            /// Return a Finder set to the start of the list.  Despite the
            /// name, this can search in either direction: it was chosen for
            /// easier autocomplete.
            pub fn forwardFinder(m: *Matcher, list: *List) Finder {
                var the_finder = m.finder(list);
                the_finder.fromFirst();
                return the_finder;
            }

            /// Return a Finder set to the end of the list.  Despite the
            /// name, this can search in either direction: it was chosen for
            /// easier autocomplete.
            pub fn backwardFinder(m: *Matcher, list: *List) Finder {
                var the_finder = m.finder(list);
                the_finder.fromLast();
                return the_finder;
            }

            pub const Finder = struct {
                this: ?*Node = null,
                m: *Matcher,
                fwd: bool = true,
                list: *List,

                /// Start iteration from the first node of the list.
                pub fn fromFirst(f: *Finder) void {
                    f.this = f.list.first;
                    f.fwd = true;
                }

                /// Start iteration from the last node of the list.
                pub fn fromLast(f: *Finder) void {
                    f.this = f.list.last;
                    f.fwd = false;
                }

                /// Return the next matching Node, advancing.  The Node is
                /// not removed.
                pub fn next(f: *Finder) ?*Node {
                    f.fwd = true;
                    if (f.this) |it| {
                        f.this = f.m.findNext(it);
                        return f.this;
                    } else return null;
                }

                /// Return the previous matching node, advancing.  The Node is
                /// not removed.
                pub fn prev(f: *Finder) ?*Node {
                    f.fwd = false;
                    if (f.this) |it| {
                        f.this = f.m.findPrev(it);
                        return f.this;
                    } else return null;
                }

                /// Return the next matching node, without advancing.  The Node is
                /// not removed.
                pub fn peekNext(f: *Finder) ?*Node {
                    if (f.this) |it| {
                        return f.m.findNext(it);
                    }
                }

                /// Return the previous matching node, without advancing.  The Node is
                /// not removed.
                pub fn peekPrev(f: *Finder) ?*Node {
                    if (f.this) |it| {
                        return f.m.findPrev(it);
                    }
                }

                /// Remove the node from the list.  Use this when iterating or you
                /// will probably lose your place (the integrity of the list will
                /// not be affected).
                pub fn remove(f: *Finder, node: *Node) void {
                    if (f.this == node) {
                        if (f.fwd) {
                            f.this = @field(f.this.?, Link.next);
                        } else {
                            f.this = @field(f.this.?, Link.prev);
                        }
                    }
                    f.list.remove(node);
                }

                /// Remove the node from the list, and return it.  Use this
                /// when iterating or you will probably lose your place (the
                /// integrity of the list will not be affected).
                pub fn pop(f: *Finder, node: *Node) *Node {
                    f.remove(node);
                    return node;
                }
            };
        };

        /// A doubly-linked list of `*Node`, comprising the first and last
        /// elements of the list.  The API preserves the following properties:
        ///
        /// - If there is a first node, there will be a last.
        /// - The last node's forward-field will be `null`, as will the first node's
        ///   backward-field.  This type is not suitable for representing a section
        ///   of a list; those can be useful to have, but this is not the data structure
        ///   with which to have them.  It is conceivable that Zelda will grow such a
        ///   data structure someday, although `struct { *Node, *Node }` is probably
        ///   adequate.
        /// - Nodes removed from the list are mutually removed from the list, that is,
        ///   the list is also removed from the node.
        /// - Nodes emplaced onto the list are asserted to be in a condition where
        ///   doing so will not break some other list.  Generally this means that they
        ///   are "solo", that is, both links `null`, not always.
        ///
        /// The API also asserts these properties often, so if your code does any
        /// direct manipulation of the list, take care to maintain them.
        pub const List = struct {
            first: ?*Node,
            last: ?*Node,

            pub const empty: List = .{ .first = null, .last = null };

            /// Inserts `new_node` after `existing_node`, adjusting `list.last`
            /// if needed. `new_node` is asserted to be `.solo` (null on both
            /// links). `existing_node` is assumed to be some member of the
            /// list.
            pub fn emplaceForward(list: *List, existing_node: *Node, new_node: *Node) void {
                assert(@field(new_node, link_field).positionInList() == .solo);
                @field(existing_node, link_field).emplaceForward(new_node);
                // If new_node is inserted at the end of the list, its 'next' will be null:
                if (@field(new_node, next) == null) {
                    assert(@field(list.last.?, next) == new_node);
                    list.last = new_node;
                }
            }

            /// Inserts `new_node` before `existing_node`, adjusting
            /// `list.first` if needed. `new_node` is asserted to be `.solo`
            /// (null on both links). `existing_node` is assumed to be some
            /// member of the list.
            pub fn emplaceBackward(list: *List, existing_node: *Node, new_node: *Node) void {
                @field(existing_node, link_field).emplaceBackward(new_node);
                // If new_node is inserted at the front of the list, its 'prev' will be null:
                if (@field(new_node, prev) == null) {
                    assert(@field(list.first.?, prev) == new_node);
                    list.first = new_node;
                }
            }

            /// Concatenate `list2` onto the end of `list1`, removing all
            /// entries from the former.
            ///
            /// Arguments:
            ///     list1: the list to concatenate onto
            ///     list2: the list to be concatenated
            pub fn concatByMoving(list1: *List, list2: *List) void {
                const l2_first = list2.first orelse {
                    assert(list2.last == null);
                    return;
                };
                if (list1.last) |l1_last| {
                    assert(@field(l1_last, next) == null);
                    @field(l1_last, next) = list2.first;
                    assert(@field(l2_first, prev) == null);
                    @field(l2_first, prev) = list1.last;
                } else {
                    // list1 was empty
                    list1.first = list2.first;
                }
                list1.last = list2.last;
                list2.first = null;
                list2.last = null;
            }

            /// Extract the range from `from` to `to` as a new linked list,
            /// healing the gap in the list thereby created.  Assumes that
            /// `from` and `to` are valid members of `list`, and that `to` may
            /// be found in the `next` (aka forward) direction starting from
            /// `from`.  No `prev` equivalent is provided, simply switch `from`
            /// and `to`.  It is valid for `from` to be `list.first`, for
            /// `to` to be `list.last`, or for `to` and `from` to be identical.
            pub fn extractRange(list: *List, from: *Node, to: *Node) List {
                if (from == to) {
                    list.remove(from);
                    return .{ .first = from, .last = to };
                }
                const from_prev = @field(from, link_field).unlinkBackward();
                const to_next = @field(to, link_field).unlinkForward();
                if (from_prev) |now_prev| {
                    if (to_next) |now_next| {
                        // These were both middle nodes
                        @field(now_prev, next) = now_next;
                        @field(now_next, prev) = now_prev;
                    } else {
                        // `to` has to be the last node:
                        assert(list.last == to);
                        // so now, now_prev is the last
                        list.last = now_prev;
                    }
                } else {
                    // `from` was the first:
                    assert(from == list.first);
                    // We need to know if
                    // `to` was the last so we can make the list empty.
                    if (to_next) |now_next| {
                        // It was not:
                        list.first = now_next;
                    } else {
                        // It was:
                        list.first = null;
                        list.last = null;
                    }
                }
                return .{ .first = from, .last = to };
            }

            /// Splices `list2` forward of the parameter `node`.  When this
            /// function returns, `list2` will be empty.  This is valid to
            /// call when `node` is either the first or the last node on the
            /// receiver list, but if this is known to be the case, prefer
            /// `concatByMoving`.  It is assumed that `list` has contents (at
            /// least `node`), and checked illegal behavior if `list2` does not.
            pub fn spliceForwardOf(list: *List, node: *Node, list2: *List) void {
                @field(node, link_field).spliceForward(list2);
                if (list.last == node) {
                    list.last = list2.last;
                }
                list2.first = null;
                list2.last = null;
            }

            /// Splices `list2` backward of the parameter `node`.  When this
            /// function returns, `list2` will be empty.  This is valid to
            /// call when `node` is either the first or the last node on the
            /// receiver list, but if this is known to be the case, prefer
            /// `concatByMoving`.  It is assumed that `list` has contents (at
            /// least `node`), and checked illegal behavior if `list2` does not.
            pub fn spliceBackwardOf(list: *List, node: *Node, list2: *List) void {
                @field(node, link_field).spliceBackward(list2);
                if (list.first == node) {
                    list.first = list2.first;
                }
                list2.first = null;
                list2.last = null;
            }

            /// Insert a new node at the end of the list.  Asserts the node
            /// is `.solo`.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn append(list: *List, new_node: *Node) void {
                assert(@field(new_node, link_field).positionInList() == .solo);
                if (list.last) |last| {
                    // Insert after last.
                    list.emplaceForward(last, new_node);
                } else {
                    // Empty list.
                    list.prepend(new_node);
                }
            }

            /// Insert a new node at the beginning of the list.  Asserts the
            /// node is `.solo`.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn prepend(list: *List, new_node: *Node) void {
                assert(@field(new_node, link_field).positionInList() == .solo);
                if (list.first) |first| {
                    // Insert before first.
                    list.emplaceBackward(first, new_node);
                } else {
                    // Empty list.
                    list.first = new_node;
                    list.last = new_node;
                }
            }

            /// Remove a node from the list.  Assumes this node belongs to
            /// this list.  O(1).
            ///
            /// Arguments:
            ///     node: Pointer to the node to be removed.
            pub fn remove(list: *List, node: *Node) void {
                switch (@field(node, link_field).positionInList()) {
                    .first => {
                        list.first = @field(node, link_field).unlinkForward();
                    },
                    .last => {
                        list.last = @field(node, link_field).unlinkBackward();
                    },
                    .middle => @field(node, link_field).removeSelfFromList(),
                    .solo => {},
                }
                assert(@field(node, link_field).positionInList() == .solo);
            }

            /// Remove and return the last node in the list.
            ///
            /// Returns:
            ///     A pointer to the last node in the list.
            pub fn pop(list: *List) ?*Node {
                const last = list.last orelse return null;
                list.remove(last);
                return last;
            }

            /// Remove and return the first node in the list.
            ///
            /// Returns:
            ///     A pointer to the first node in the list.
            pub fn popFirst(list: *List) ?*Node {
                const first = list.first orelse return null;
                list.remove(first);
                return first;
            }

            /// Remove a node from the list, returning that same node.
            /// This is just `remove` in the functional style.
            pub fn popNode(list: *List, node: *Node) *Node {
                list.remove(node);
                return node;
            }

            /// Iterate over all nodes, returning the count.
            ///
            /// This operation is O(N).  Consider tracking the length separately
            /// rather than computing it.
            pub fn len(list: List) usize {
                var count: usize = 0;
                var it: ?*const Node = list.first;
                while (it) |n| : (it = @field(n, next)) count += 1;
                return count;
            }

            /// Answer whether the list is empty.
            pub fn isEmpty(list: List) bool {
                if (list.first == null) {
                    assert(list.last == null);
                    return true;
                }
                assert(list.last != null);
                return false;
            }

            /// Answer whether the list is 'well-formed': null at
            /// both ends, properly interlinked, and acyclic.  Useful
            /// in diagnosis and testing.  Since this detects and breaks
            /// cycles, it does not respect the iteration limit.
            pub fn isWellFormed(list: List) bool {
                if (list.first == null or list.last == null) return false;
                if (list.first == list.last) return true;
                // Since we know first is bounded, any forward-cycle will
                // eventually fail the back-link test, and we can't be in a
                // proper cycle because we start from first.
                var m_node = list.first;
                while (@field(m_node.?, next)) |next_node| {
                    if (@field(next_node, prev) != m_node) return false;
                    m_node = next_node;
                }
                return m_node == list.last;
            }

            inline fn mustBeBounded(list: List) void {
                if (list.first) |first| {
                    assert(@field(first, prev) == null);
                    if (list.last) |last| {
                        assert(@field(last, next) == null);
                    } else {
                        assert(false);
                    }
                } else {
                    assert(list.last == null);
                }
            }

            /// Adjust one, or the other, of the ends of the list, backward or
            /// forward by precisely one link, then assert that the list is
            /// properly bounded.  This is deliberately strict, it repairs one
            /// (1) weird thing done to a list if called immediately after the
            /// weird thing.  Users of the List API should have no need to call
            /// this function.
            pub fn adjustEnds(list: *List) void {
                if (@field(list.first.?, prev) != null) {
                    list.first = @field(list.first.?, prev);
                    mustBeBounded(list);
                } else if (@field(list.last.?, next) != null) {
                    list.last = @field(list.last.?, next);
                    mustBeBounded(list);
                }
            }

            /// Sort the list in-place into ascending order.
            pub fn sortAscending(list: *List) void {
                if (list.first == null) return;
                list.first, list.last = mergeSortFn(lessThan)(list.first.?);
            }

            /// Sort the list in-place into descending order.
            pub fn sortDescending(list: *List) void {
                if (list.first == null) return;
                list.first, list.last = mergeSortFn(greaterThan)(list.first.?);
            }

            /// Search forward from the first node on the list, placing the argument
            /// node where it belongs if the list were to be in ascending order.
            pub fn insertAscendingForward(list: *List, node: *Node) void {
                if (list.first == null) {
                    assert(list.last == null);
                    list.prepend(node);
                    return;
                }
                mustBeBounded(list);
                insertSortFn(lessThanEq, next)(list.first.?);
                adjustEnds(list);
            }

            /// Search backward from the last node on the list, placing the argument
            /// node where it belongs if the list were to be in ascending order.
            pub fn insertAscendingBackward(list: *List, node: *Node) void {
                if (list.first == null) {
                    assert(list.last == null);
                    list.prepend(node);
                    return;
                }
                mustBeBounded(list);
                insertSortFn(lessThanEq, prev)(list.last.?);
                adjustEnds(list);
            }

            /// Search forward from the first node on the list, placing the argument
            /// node where it belongs if the list were to be in descending order.
            pub fn insertDescendingForward(list: *List, node: *Node) void {
                if (list.first == null) {
                    assert(list.last == null);
                    list.prepend(node);
                    return;
                }
                mustBeBounded(list);
                insertSortFn(greaterThanEq, next)(list.first.?);
                adjustEnds(list);
            }

            /// Search backward from the last node on the list, placing the argument
            /// node where it belongs if the list were to be in descending order.
            pub fn insertDescendingBackward(list: *List, node: *Node) void {
                if (list.first == null) {
                    assert(list.last == null);
                    list.prepend(node);
                    return;
                }
                mustBeBounded(list);
                insertSortFn(greaterThanEq, prev)(list.last.?);
                adjustEnds(list);
            }

            /// Answer if the list is sorted in ascending order.  Perhaps surprisingly,
            /// an empty list will answer `true`.
            pub fn isOrderedAscending(list: *List) bool {
                if (list.first == null) return true;
                return inOrderFn(lessThanEq)(list.first.?);
            }

            /// Answer if the list is sorted in descending order.  Perhaps surprisingly,
            /// an empty list will answer `true`.
            pub fn isOrderedDescending(list: *List) bool {
                if (list.first == null) return true;
                return inOrderFn(greaterThanEq)(list.first.?);
            }
        };

        //| Ordering Impl

        inline fn orderGuard() void {
            if (!has_order)
                @compileError(
                    \\This mixin was not configured with an order function, and
                    \\cannot be sorted without one.  Zelda will find a public
                    \\declaration `zeldaOrderFn`, expecting the signature
                    \\
                    \\    fn(*const Node, *const Node) callconv(.@"inline") zelda.Order;
                    \\
                    \\Although the calling convention and specific enum are never checked, this
                    \\will allow the optimizer to generate the best code in the most cases.
                    \\
                    \\When configuring the mixin manually, provide the name of the declaration as
                    \\a string for the last argument, rather than `null`.
                );
        }

        inline fn lessThan(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) == .lt;
        }

        inline fn lessThanEq(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) != .gt;
        }

        inline fn greaterThan(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) == .gt;
        }

        inline fn greaterThanEq(n1: *const Node, n2: *const Node) bool {
            return @field(Node, order_name)(n1, n2) != .lt;
        }

        fn insertSortFn(
            orderFn: fn (*Node, *Node) callconv(.@"inline") bool,
            comptime direction: []const u8,
        ) fn (*Node, *Node) *Node {
            return struct {
                pub fn insert(head: *Node, node: *Node) void {
                    orderGuard();
                    const is_next = std.mem.eql(u8, direction, next);
                    if (orderFn(node, head)) {
                        if (is_next)
                            @field(head, link_field).insertBefore(node)
                        else
                            @field(head, link_field).insertAfter(node);
                        return;
                    }
                    var m_next = @field(head, direction);
                    var last = head;
                    var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                    while (m_next) |next_node| {
                        if (has_limit) limit += 1;
                        if (orderFn(node, next_node)) {
                            if (is_next)
                                @field(next_node, link_field).insertBefore(node)
                            else
                                @field(next_node, link_field).insertAfter(node);
                            return;
                        }
                        last = next_node;
                        m_next = @field(next_node, direction);
                        if (has_limit) if (limit >= seek_limit) @panic("insertSorted exceeded seek limit");
                    }
                    if (is_next)
                        @field(head, link_field).insertAfter(node)
                    else
                        @field(head, link_field).insertBefore(node);
                    return;
                }
            }.insert;
        }

        fn mergeSortFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) struct { *Node, *Node } {
            return struct {
                pub fn msort(n: *Node) struct { *Node, *Node } {
                    orderGuard();
                    var ep: ?*Node = null;
                    var set: [LISTSIZE]?*Node = .{null} ** LISTSIZE;
                    var m_list: ?*Node = n;
                    var first = true;
                    while (m_list) |list| {
                        ep = list;
                        // First, "gallop" past any already-sorted values,
                        // this brings the merge down to O(n) for an already-
                        // sorted list.
                        var m_gallop: ?*Node = list;
                        var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                        while (m_gallop) |gallop| {
                            if (has_limit) limit += 1;
                            if (@field(gallop, next)) |g_next| {
                                if (orderFn(gallop, g_next)) {
                                    m_gallop = g_next;
                                } else {
                                    m_list = g_next;
                                    @field(gallop, next) = null;
                                    break;
                                }
                            } else {
                                if (first) {
                                    // sorted!
                                    return .{ n, gallop };
                                }
                                m_list = null;
                                break;
                            }
                            if (has_limit) if (limit >= seek_limit) @panic("mergeSort exceeded seek limit");
                        }
                        first = false;
                        var i: usize = 0;
                        while (i < LISTSIZE - 1 and set[i] != null) : (i += 1) {
                            ep = merge(set[i], ep);
                            set[i] = null;
                        }
                        set[i] = merge(set[i], ep);
                    }
                    ep = null;
                    // Compress the fragments.  We could just count them but
                    // it takes the same amount of time.
                    var off: usize = 0;
                    for (0..LISTSIZE) |i| {
                        if (set[i]) |_| {
                            set[i - off] = set[i];
                        } else {
                            off += 1;
                        }
                    } // The amount remaining is just:
                    var amt = LISTSIZE - off;
                    assert(amt > 0);
                    var i: usize = 0;
                    while (amt > 1) {
                        ep = merge(set[i].?, ep);
                        i += 1;
                        amt -= 1;
                    }
                    // Ep might be null here, if we only have one list,
                    // but that's ok:
                    return mergeFinal(set[i], ep);
                }

                // Merge two linked lists, given the head. Either the first or the
                // second may be null: by construction, they will never both be
                // null, but it's harmless to our purposes to return a `?*T`, so
                // we wouldn't benefit from that fact and don't take advantage of it.
                fn merge(maybe_a: ?*Node, maybe_b: ?*Node) ?*Node {
                    if (maybe_a == null) return maybe_b;
                    if (maybe_b == null) return maybe_a;
                    var a: ?*Node = maybe_a;
                    var b: ?*Node = maybe_b;
                    const head: *Node = if (orderFn(a.?, b.?)) head: {
                        const h = a.?;
                        a = @field(h, next);
                        break :head h;
                    } else head: {
                        const h = b.?;
                        b = @field(h, next);
                        break :head h;
                    };
                    var ptr: *Node = head;
                    while (a != null and b != null) {
                        const a_ptr = a.?;
                        const b_ptr = b.?;
                        if (orderFn(a_ptr, b_ptr)) {
                            @field(ptr, next) = a_ptr;
                            ptr = a_ptr;
                            a = @field(a_ptr, next);
                        } else {
                            @field(ptr, next) = b_ptr;
                            ptr = b_ptr;
                            b = @field(b_ptr, next);
                        }
                    }
                    if (a) |a_ptr| {
                        @field(ptr, next) = a_ptr;
                    } else {
                        @field(ptr, next) = b;
                    }
                    return head;
                }

                // Final merge: "a" is never null, but we need a variable anyway, so it's
                // convenient to cast here.  This time we retain or find the tail and
                // return it as well, while fixing up all backlinks.
                fn mergeFinal(maybe_a: ?*Node, maybe_b: ?*Node) struct { *Node, *Node } {
                    assert(maybe_a != null);
                    if (maybe_b == null) {
                        var m_ptr = maybe_a;
                        @field(m_ptr.?, prev) = null;
                        while (@field(m_ptr.?, next)) |n| {
                            @field(n, prev) = m_ptr;
                            m_ptr = n;
                        }
                        return .{ maybe_a.?, m_ptr.? };
                    }
                    var a: ?*Node = maybe_a;
                    var b: ?*Node = maybe_b;
                    const head: *Node = if (orderFn(a.?, b.?)) head: {
                        const h = a.?;
                        a = @field(h, next);
                        break :head h;
                    } else head: {
                        const h = b.?;
                        b = @field(h, next);
                        break :head h;
                    };
                    @field(head, prev) = null;
                    var ptr: *Node = head;
                    while (a != null and b != null) {
                        const a_ptr = a.?;
                        const b_ptr = b.?;
                        if (orderFn(a_ptr, b_ptr)) {
                            @field(ptr, next) = a_ptr;
                            @field(a_ptr, prev) = ptr;
                            ptr = a_ptr;
                            a = @field(a_ptr, next);
                        } else {
                            @field(ptr, next) = b_ptr;
                            @field(b_ptr, prev) = ptr;
                            ptr = b_ptr;
                            b = @field(b_ptr, next);
                        }
                    }
                    // We advance one list at a time, so one of these must
                    // exist (and the other does not, per the exit condition
                    // of the while loop):
                    var tail_ptr: ?*Node =
                        if (a) |a_ptr| a_ptr else if (b) |b_ptr| b_ptr else unreachable;
                    @field(ptr, next) = tail_ptr;
                    @field(tail_ptr.?, prev) = ptr;

                    while (@field(tail_ptr.?, next)) |n| {
                        @field(n, prev) = tail_ptr;
                        tail_ptr = n;
                    }
                    return .{ head, tail_ptr.? };
                }
            }.msort;
        }

        fn inOrderFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) bool {
            return struct {
                pub fn inorder(head: *Node) bool {
                    orderGuard();
                    var this: *Node = head;
                    var limit: (if (has_limit) usize else void) = if (has_limit) 0 else {};
                    while (@field(this, next)) |next_node| {
                        if (has_limit) limit += 1;
                        if (orderFn(this, next_node)) {
                            this = next_node;
                        } else {
                            return false;
                        }
                        if (has_limit) if (limit >= seek_limit) @panic("inOrder exceeded seek limit");
                    } else {
                        return true;
                    }
                }
            }.inorder;
        }
    };
}

/// The size of the array used to hold node pointers
/// during merge sorts.
const LISTSIZE = 32;

// Tests

const testing = std.testing;
const expectEqual = testing.expectEqual;

const Hyrule = struct {
    data: usize,
    link: Link = .{},
    next_member: ?*Hyrule = null,

    pub fn init(data: usize) Hyrule {
        return .{ .data = data };
    }

    pub const Link = aLinkToThePast(Hyrule);
};

test Hyrule {
    var this: Hyrule = .init(23);
    var that: Hyrule = .init(42);
    this.link.insertAfter(&that);
    try expectEqual(this.next_member.?, &that);
    _ = this.link.swap();
    try expectEqual(that.next_member.?, &this);
    _ = that.link.swap();
    const that_again = this.link.removeNext().?;
    try expectEqual(&that, that_again);
}

test "A Link to the Past" {
    const L = struct {
        data: u32,
        node: ?*@This() = null,
        link: Link = .{},

        pub const Link = singlyLinkedList(@This(), .node, null);
        pub const List = Link.List;
    };

    var list: L.List = .empty;

    try testing.expect(list.len() == 0);

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list.prepend(&two); // {2}
    two.link.insertAfter(&five); // {2, 5}
    list.prepend(&one); // {1, 2, 5}
    two.link.insertAfter(&three); // {1, 2, 3, 5}
    three.link.insertAfter(&four); // {1, 2, 3, 4, 5}

    try testing.expect(list.len() == 5);

    // Traverse forwards.
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |next| : (it = next.node) {
            try testing.expect(next.data == index);
            index += 1;
        }
    }

    _ = list.popFirst(); // {2, 3, 4, 5}
    _ = list.remove(&five); // {2, 3, 4}
    _ = two.link.removeNext(); // {2, 4}

    try testing.expect(list.first.?.data == 2);
    try testing.expect(list.first.?.node.?.data == 4);
    try testing.expect(list.first.?.node.?.node == null);

    list.reverse();

    try testing.expect(list.first.?.data == 4);
    try testing.expect(list.first.?.node.?.data == 2);
    try testing.expect(list.first.?.node.?.node == null);
}

const Sorted = struct {
    val: u32,
    next_val: ?*S = null,
    mixer: Link = .{},

    pub const empty: S = .{ .val = undefined };

    pub const ZELDA_SEEK_LIMIT = if (false) null else 512;

    pub const S = @This();
    pub const Link = aLinkToThePast(S);

    pub inline fn zeldaOrderFn(a: *const S, b: *const S) Order {
        const sign: i64 = @as(i64, a.val) - @as(i64, b.val);
        if (sign < 0)
            return .lt
        else if (sign == 0)
            return .eq
        else
            return .gt;
    }
};

test "Sorted singly-linked list" {
    try testing.expect(Sorted.Link.has_order);
    //| Merge sorts
    var sorts: [6]Sorted = .{Sorted.empty} ** 6;
    for (0..6) |i| {
        sorts[i].val = @intCast(12 - i);
    }
    for (0..5) |i| {
        sorts[i].next_val = &sorts[i + 1];
    }
    {
        const sorted = sorts[0].mixer.sortAscending();
        try expectEqual(sorted, &sorts[5]);
        const downsorted = sorted.mixer.sortDescending();
        try expectEqual(downsorted, &sorts[0]);
    }
    for (0..5) |i| {
        try expectEqual(sorts[i].next_val, &sorts[i + 1]);
    }
    //| Sorted insertion
    for (0..6) |i| {
        sorts[i].val = @intCast((i + 1) * 2);
        if (i < 5) {
            try expectEqual(sorts[i].next_val, &sorts[i + 1]);
        }
    }
    try expectEqual(6, sorts[0].mixer.countChildren() + 1);
    var one: Sorted = .{ .val = 1 };
    {
        const sorted = sorts[0].mixer.insertOrderedAscending(&one);
        try expectEqual(7, sorted.mixer.countChildren() + 1);
        try expectEqual(sorted, &one);
    }
    var three: Sorted = .{ .val = 3 };
    {
        const sorted = one.mixer.insertOrderedAscending(&three);
        try expectEqual(8, sorted.mixer.countChildren() + 1);
        try expect(sorted.mixer.isOrderedAscending());
    }
    var five: Sorted = .{ .val = 5 };
    {
        const rsorted = one.mixer.sortDescending();
        try expect(rsorted.mixer.isOrderedDescending());
        const still_rsorted = rsorted.mixer.insertOrderedDescending(&five);
        try expectEqual(9, rsorted.mixer.len());
        try expectEqual(rsorted, still_rsorted);
        try expect(still_rsorted.mixer.isOrderedDescending());
        const resorted = rsorted.mixer.reverse();
        try expect(resorted.mixer.isOrderedAscending());
        const reresorted = resorted.mixer.reverse();
        try expect(reresorted.mixer.isOrderedDescending());
        const antireresorted = reresorted.mixer.sortDescending();
        try expect(antireresorted.mixer.isOrderedDescending());
    }
}

test "more sorts" {
    var sorts: [512]Sorted = .{Sorted.empty} ** 512;
    var seed: u64 = undefined;
    var prng = std.Random.DefaultPrng.init(rand: {
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :rand seed;
    });
    errdefer std.debug.print("Seed on fail: 0x{x}", .{seed});
    for (0..512) |i| {
        sorts[i].val = prng.random().int(u32);
        if (i < 511) {
            sorts[i].next_val = &sorts[i + 1];
        }
    }
    {
        const sorted = sorts[0].mixer.sortAscending();
        try expect(sorted.mixer.isOrderedAscending());
        const dsorted = sorted.mixer.sortDescending();
        try expect(dsorted.mixer.isOrderedDescending());
    }
    for (0..512) |i| {
        sorts[i].val = prng.random().int(u32);
        if (i < 511) {
            sorts[i].next_val = &sorts[i + 1];
        }
    }
    sorts[511].next_val = null;
    {
        var list = sorts[0].mixer.toList();
        list.sortAscending();
        try expect(list.first.?.mixer.isOrderedAscending());
        const biggest = list.last;
        list.sortDescending();
        try expect(list.first.?.mixer.isOrderedDescending());
        try expectEqual(biggest, list.first.?);
        try expectEqual(512, list.len());
    }
    for (0..512) |i| {
        sorts[i].val = prng.random().int(u32);
        if (i < 511) {
            sorts[i].next_val = &sorts[i + 1];
        }
    }
    sorts[511].next_val = null;
    {
        var list = sorts[0].mixer.toSortedListAscending();
        try expect(list.first.?.mixer.isOrderedAscending());
        const biggest = list.last;
        list.sortDescending();
        try expect(list.first.?.mixer.isOrderedDescending());
        list.sortDescending();
        try expect(list.first.?.mixer.isOrderedDescending());
        try expectEqual(biggest, list.first.?);
        try expectEqual(512, list.len());
        var split_at = prng.random().intRangeLessThan(u32, 0, 512);
        while (&sorts[split_at] == list.first or &sorts[split_at] == list.last) {
            split_at = prng.random().intRangeLessThan(u32, 0, 512);
        }
        var half_list = list.splitAfter(&sorts[split_at]);
        half_list.concat(&list);
        try expectEqual(512, half_list.len());
        half_list.sortDescending();
        try expect(half_list.first.?.mixer.isOrderedDescending());
        try expect(half_list.isOrderedDescending());
        try expect(!half_list.isOrderedAscending());
        half_list.sortAscending();
        try expect(half_list.first.?.mixer.isOrderedAscending());
        try expect(half_list.isOrderedAscending());
        try expectEqual(512, half_list.len());
        const remove_at = prng.random().intRangeLessThan(u32, 0, 512);
        half_list.remove(&sorts[remove_at]);
        sorts[remove_at].val = std.math.maxInt(u32);
        try expectEqual(511, half_list.first.?.mixer.len());
        half_list.insertOrderedAscending(&sorts[remove_at]);
        try expect(half_list.isOrderedAscending());
        try expectEqual(512, half_list.first.?.mixer.len());
    }
}

test "A Link Between Worlds" {
    const L = struct {
        data: u32,
        forward: ?*@This() = null,
        backward: ?*@This() = null,
        link: Link = .{},

        pub const Link = aLinkBetweenWorlds(@This());

        pub const List = Link.List;
    };

    var list: L.List = .empty;

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list.append(&two); // {2}
    list.append(&five); // {2, 5}
    list.prepend(&one); // {1, 2, 5}
    list.emplaceBackward(&five, &four); // {1, 2, 4, 5}
    list.emplaceForward(&two, &three); // {1, 2, 3, 4, 5}

    try testing.expect(list.first != null);
    try testing.expect(list.last != null);

    try testing.expect(one.link.inDoubleLinkedListForward());
    try testing.expect(five.link.inDoubleLinkedListBackward());

    // Swap

    try testing.expectEqual(2, three.backward.?.data);

    three.link.swapForward();
    try testing.expectEqual(4, three.backward.?.data);
    try testing.expectEqual(5, three.forward.?.data);
    try testing.expect(one.link.inDoubleLinkedListForward());
    try testing.expect(five.link.inDoubleLinkedListBackward());

    three.link.swapBackward();
    try testing.expectEqual(4, three.forward.?.data);
    try testing.expectEqual(2, three.backward.?.data);
    try testing.expect(one.link.inDoubleLinkedListForward());
    try testing.expect(five.link.inDoubleLinkedListBackward());

    four.link.swapForward();
    try testing.expectEqual(5, three.forward.?.data);
    try testing.expectEqual(null, four.forward);
    try testing.expect(one.link.inDoubleLinkedListForward());
    try testing.expect(five.link.inDoubleLinkedListBackward());

    four.link.swapBackward();
    try testing.expectEqual(5, four.forward.?.data);
    try testing.expectEqual(null, five.forward);
    try testing.expect(one.link.inDoubleLinkedListForward());
    try testing.expect(five.link.inDoubleLinkedListBackward());

    try testing.expect(!one.link.inCycleForward());
    try testing.expect(!five.link.inCycleBackward());

    // Traverse forwards.
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.forward) {
            try testing.expectEqual(index, node.data);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Traverse backwards.
    {
        var it = list.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.backward) {
            try testing.expectEqual((6 - index), node.data);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    try testing.expectEqual(1, list.popFirst().?.data); // {2, 3, 4, 5}
    try testing.expectEqual(2, list.first.?.data);
    try testing.expectEqual(5, list.last.?.data);

    try testing.expectEqual(5, list.pop().?.data); // {2, 3, 4}
    try testing.expectEqual(4, list.last.?.data);

    list.remove(&three); // {2, 4}
    try testing.expectEqual(2, list.first.?.data);
    try testing.expectEqual(4, list.last.?.data);

    try testing.expect(list.len() == 2);
}

test "concatenation and splicing" {
    const L = struct {
        data: u32,
        next: ?*@This() = null,
        prev: ?*@This() = null,
        link: Link = .{},

        pub const Link = doublyLinkedList(@This(), .next, "prev", null);
        pub const List = Link.List;
    };

    var list1: L.List = .empty;
    var list2: L.List = .empty;

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list1.append(&one);
    list1.append(&two);
    list2.append(&three);
    list2.append(&four);
    list2.append(&five);

    list1.concatByMoving(&list2);

    try testing.expect(list1.last == &five);
    try testing.expect(list1.len() == 5);
    try testing.expect(list2.first == null);
    try testing.expect(list2.last == null);
    try testing.expect(list2.isEmpty());
    try testing.expect(list2.len() == 0);

    // Traverse forwards.
    {
        var it = list1.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            try testing.expect(node.data == index);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Traverse backwards.
    {
        var it = list1.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            try testing.expect(node.data == (6 - index));
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Swap them back, this verifies that concatenating to an empty list works.
    list2.concatByMoving(&list1);
    try testing.expect(!list2.isEmpty());
    try testing.expect(list1.isEmpty());

    // Traverse forwards.
    {
        var it = list2.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            try testing.expect(node.data == index);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Traverse backwards.
    {
        var it = list2.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            try testing.expect(node.data == (6 - index));
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Swap again
    list1.concatByMoving(&list2);

    // Extract a range.
    var sublist = list1.extractRange(&two, &four);
    _ = &sublist;

    try testing.expect(sublist.first == &two);
    try testing.expect(sublist.last == &four);
    try testing.expect(list1.first == &one);
    try testing.expect(list1.last == &five);
    try testing.expect(list1.first == list1.last.?.prev);
    try testing.expect(list1.first.?.next == list1.last);

    // Put it back
    list1.spliceForwardOf(&one, &sublist);
    try testing.expect(sublist.isEmpty());

    // Check we got our list back
    {
        var it = list1.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            try testing.expectEqual(index, node.data);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }

    // Extract again
    sublist = list1.extractRange(&two, &four);

    try testing.expect(sublist.first == &two);
    try testing.expect(sublist.last == &four);
    try testing.expect(list1.first == &one);
    try testing.expect(list1.last == &five);
    try testing.expect(list1.first == list1.last.?.prev);
    try testing.expect(list1.first.?.next == list1.last);

    // Replace it on the other side
    list1.spliceBackwardOf(&five, &sublist);

    // Verify, backward this time.
    {
        var it = list1.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            try testing.expectEqual((6 - index), node.data);
            index += 1;
        }
        try testing.expectEqual(6, index);
    }
}

test "cycles" {
    const Kid = struct {
        next: ?*@This() = null,
        prev: ?*@This() = null,
        the_link: Link = .{},

        pub const Link = doublyLinkedList(@This(), .next, .prev, null);
        pub const List = Link.List;
    };

    var alice: Kid = .{};
    var bob: Kid = .{};
    var charlie: Kid = .{};
    var dan: Kid = .{};
    alice.the_link.emplaceForward(&bob);
    try testing.expectEqual(&bob, alice.next.?);
    try testing.expectEqual(null, alice.prev);

    bob.the_link.emplaceForward(&charlie);
    try testing.expectEqual(&charlie, bob.next.?);
    try testing.expectEqual(null, alice.prev);
    try testing.expectEqual(&bob, alice.next.?);

    charlie.the_link.emplaceForward(&alice);
    try testing.expectEqual(&alice, charlie.next.?);
    try testing.expectEqual(&bob, charlie.prev.?);
    try testing.expectEqual(&charlie, alice.prev.?);

    try testing.expectEqual(&bob, alice.next.?);
    try testing.expectEqual(&charlie, bob.next.?);
    try testing.expectEqual(&alice, charlie.next.?);

    try testing.expect(charlie.the_link.inCycleBackward());
    try testing.expect(charlie.the_link.inCycleForward());
    try testing.expect(alice.the_link.inCycleBackward());
    try testing.expect(alice.the_link.inCycleForward());
    try testing.expect(bob.the_link.inCycleBackward());
    try testing.expect(bob.the_link.inCycleForward());

    dan.next = &bob;
    try testing.expect(dan.the_link.inCycleForward());
    try testing.expect(!dan.the_link.inCycleBackward());

    var ethel: Kid = .{};
    var frank: Kid = .{};
    var glen: Kid = .{};
    glen.the_link.emplaceBackward(&frank);
    frank.the_link.emplaceBackward(&ethel);
    ethel.the_link.emplaceBackward(&glen);

    try testing.expect(ethel.the_link.inCycleBackward());
    try testing.expect(ethel.the_link.inCycleForward());
    try testing.expect(frank.the_link.inCycleBackward());
    try testing.expect(frank.the_link.inCycleForward());
    try testing.expect(glen.the_link.inCycleBackward());
    try testing.expect(glen.the_link.inCycleForward());
}

const Card = struct {
    face: FaceKind,
    suit: SuitKind,
    link: Link = .{},
    over: ?*Card = null,
    under: ?*Card = null,
    suitlink: SuitLink = .{},

    pub const FaceKind = enum(i8) {
        ace,
        two,
        three,
        four,
        five,
        six,
        seven,
        eight,
        nine,
        ten,
        jack,
        king,
        queen,
    };

    pub const SuitKind = enum(i8) {
        club,
        diamond,
        heart,
        spade,
    };

    pub const ZELDA_SEEK_LIMIT = 4097;

    pub const trump: Card = .{ .suit = .spade, .face = .ace };

    pub const Link = aLinkBetweenWorlds(Card);
    pub const SuitLink = doublyLinkedList(Card, .over, .under, "suitRank");

    pub inline fn zeldaOrderFn(c1: *const Card, c2: *const Card) Order {
        const diff = @intFromEnum(c1.face) - @intFromEnum(c2.face);
        if (diff < 0)
            return .lt
        else if (diff == 0)
            return .eq
        else
            return .gt;
    }

    pub inline fn suitRank(c1: *const Card, c2: *const Card) Order {
        const diff = @intFromEnum(c1.suit) - @intFromEnum(c2.suit);
        if (diff < 0)
            return .lt
        else if (diff == 0)
            return .eq
        else
            return .gt;
    }
};

fn cardTricks(comptime count: comptime_int) !void {
    var deck: [count]Card = .{Card.trump} ** count;
    var seed: u64 = undefined;
    var prng = std.Random.DefaultPrng.init(rand: {
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :rand seed;
    });
    errdefer std.debug.print("Seed on fail: 0x{x}\n", .{seed});
    for (0..count) |i| {
        deck[i].suit = prng.random().enumValue(Card.SuitKind);
        deck[i].face = prng.random().enumValue(Card.FaceKind);
        if (count - i == 1) break;
        deck[i].link.emplaceForward(&deck[i + 1]);
    }
    {
        var facesort = deck[prng.random().uintLessThan(usize, count)].link.toList();
        facesort.sortAscending();
        try expect(facesort.isWellFormed());
        try expect(facesort.isOrderedAscending());
        try expectEqual(count, facesort.len());
        facesort.sortDescending();
        try expect(facesort.isWellFormed());
        try expect(facesort.isOrderedDescending());
        try expectEqual(count, facesort.len());
    }
    {
        var suitsort = deck[prng.random().uintLessThan(usize, count)].suitlink.toList();
        suitsort.sortAscending();
        try expect(suitsort.isWellFormed());
        try expect(suitsort.isOrderedAscending());
        try expectEqual(count, suitsort.len());
        suitsort.sortDescending();
        try expect(suitsort.isWellFormed());
        try expect(suitsort.isOrderedDescending());
        try expectEqual(count, suitsort.len());
    }
}

test cardTricks {
    try cardTricks(52);
}

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

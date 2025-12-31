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
            while (true) {
                it = @field(it, next) orelse return it;
            }
        }

        /// Iterate over each next node, returning the count of all nodes except
        /// the starting one.  O(n).
        pub fn countChildren(link: *const Link) usize {
            const node: *const Node = cbase(link);
            var count: usize = 0;
            var it: ?*const Node = @field(node, next);
            while (it) |n| : (it = @field(n, next)) {
                count += 1;
            }
            return count;
        }

        /// Reverse the list starting from this node, returning the new head.  O(n).
        pub fn reverse(link: *Link) *Node {
            var current = base(link);
            const indirect = &current;
            while (@field(current, next)) |the_next| {
                @field(current, next) = @field(the_next, next);
                @field(the_next, next) = indirect.*;
                indirect.* = the_next;
            }
            return indirect.*;
        }

        /// Return the linked list to which this node belongs, in O(n).  It is
        /// generally preferable to maintain the list _as_ a list, rather than
        /// call this function.
        pub fn toList(link: *Link) List {
            const node = base(link);
            const last = link.findLast();
            return .{ .first = node, .last = last };
        }

        //| Ordered List Library
        //|
        //| Ideally these would only exist in the namespace if an order function
        //| were provided.  I tried making them `void` unless there's an order
        //| function, but ZLS can't see through that kind of complex comptime
        //| wizardry, which is understandable if a little sad.
        //|
        //| So everyone is going to see these, but it will be a compile error to
        //| call them unless they can do something.  This will do for now.

        /// Sort a list after this node in ascending order,
        /// returning the smallest value.
        pub fn sortAscending(link: *Link) *Node {
            orderGuard();
            const node = base(link);
            return mergeSortFn(lessThan)(node);
        }

        /// Sort a list after this node in descending order,
        /// returning the largest value.
        pub fn sortDescending(link: *Link) *Node {
            orderGuard();
            const node = base(link);
            return mergeSortFn(greaterThan)(node);
        }

        /// Insert the argument node into the list, such that if already ordered
        /// ascending, the returned list will remain in ascending order.
        /// Strictly, it will be before the first node it sees which is equal to
        /// or greater than its value.
        pub fn insertOrderedAscending(link: *Link, node: *Node) *Node {
            orderGuard();
            const head = base(link);
            return insertSortFn(lessThanEq)(head, node);
        }

        /// Answer whether the node is the head of a list in ascending order.
        /// A useful diagnostic, assertion, and testing tool, but something
        /// production code should prefer to know by construction.
        pub fn isOrderedAscending(link: *Link) bool {
            orderGuard();
            const head = base(link);
            return inOrderFn(lessThanEq)(head);
        }

        /// Answer whether the node is the head of a list in descending order.
        /// A useful diagnostic, assertion, and testing tool, but something
        /// production code should prefer to know by construction.
        pub fn isOrderedDescending(link: *Link) bool {
            orderGuard();
            const head = base(link);
            return inOrderFn(greaterThanEq)(head);
        }

        /// Insert the argument node into the list, such that if already ordered
        /// descending, the returned list will remain in descending order.
        /// Strictly, it will be before the first node it sees which is equal to
        /// or less than its value.
        pub fn insertOrderedDescending(link: *Link, node: *Node) *Node {
            orderGuard();
            const head = base(link);
            return insertSortFn(greaterThanEq)(head, node);
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
                    if (orderFn(node, head)) {
                        @field(node, next) = head;
                        return node;
                    }
                    var m_next = @field(head, next);
                    var last = head;
                    while (m_next) |next_node| {
                        if (orderFn(node, next_node)) {
                            @field(last, next) = node;
                            @field(node, next) = next_node;
                            return head;
                        }
                        last = next_node;
                        m_next = @field(next_node, next);
                    }
                    @field(last, next) = node;
                    return head;
                }
            }.insert;
        }

        fn inOrderFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) bool {
            return struct {
                pub fn inorder(head: *Node) bool {
                    var this: *Node = head;
                    while (@field(this, next)) |next_node| {
                        if (orderFn(this, next_node)) {
                            this = next_node;
                        } else {
                            return false;
                        }
                    } else {
                        return true;
                    }
                }
            }.inorder;
        }

        const LISTSIZE = 32;

        fn mergeSortFn(orderFn: fn (*Node, *Node) callconv(.@"inline") bool) fn (*Node) *Node {
            return struct {
                pub fn msort(n: *Node) *Node {
                    var ep: ?*Node = null;
                    var set: [LISTSIZE]?*Node = .{null} ** LISTSIZE;
                    var m_list: ?*Node = n;
                    // TODO: Galloping pass
                    while (m_list) |list| {
                        ep = list;
                        m_list = @field(list, next);
                        @field(ep.?, next) = null;
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
            /// it is not, the program will crash, or worse.  This might be
            /// faster to use than plain `remove`, or it might just be more
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

            /// Reverse the order of the nodes in the list, in-place, in
            /// O(n).  Legal to call on an empty list.
            pub fn reverse(list: *List) void {
                reverseNode(&list.first);
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
                assert(list.last != null and list.last != node);
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
            /// This operation is O(n). Consider tracking the length separately
            /// rather than computing it.
            pub fn len(list: *const List) usize {
                if (list.first) |n| {
                    return 1 + @field(n, link_field).countChildren();
                } else {
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

            // Reverse the list starting from this node in-place.
            fn reverseNode(indirect: *?*Node) void {
                if (indirect.* == null) {
                    return;
                }
                var current: *Node = indirect.*.?;
                while (@field(current, next)) |the_next| {
                    @field(current, next) = @field(the_next, next);
                    @field(the_next, next) = indirect.*;
                    indirect.* = the_next;
                }
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
    const m_next: ?[]const u8 = if (@hasField(@TypeOf(info), "next")) info.next else null;
    const m_prev: ?[]const u8 = if (@hasField(@TypeOf(info), "prev")) info.prev else null;
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

        const the_names: struct { []const u8, []const u8 } = if (m_next) |the_next| .{ the_next, m_prev.? } else next_names: {
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

        inline fn base(link: *Link) *Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        inline fn cbase(link: *const Link) *const Node {
            return @alignCast(@fieldParentPtr(link_field, link));
        }

        /// Insert the receiver node after the parameter node.
        pub fn insertAfter(link: *Link, new_node: *Node) void {
            const node = base(link);
            @field(new_node, prev) = node;
            if (@field(node, next)) |next_node| {
                // Intermediate node.
                @field(new_node, next) = next_node;
                @field(next_node, prev) = new_node;
            } else {
                // Last element of the list.
            }
            @field(node, next) = new_node;
        }

        /// Insert the receiver node before the parameter node.
        pub fn insertBefore(link: *Link, new_node: *Node) void {
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

        /// Unlink from the next structure, if any.  Returns the unlinked
        /// struct, or null.
        pub fn unlinkNext(link: *Link) ?*Node {
            const node = base(link);
            const this_next = @field(node, next) orelse return null;
            @field(this_next, prev) = null;
            @field(node, next) = null;
            return this_next;
        }

        /// Unlink from the previous structure, if any.  Returns the unlinked
        /// struct, or null.
        pub fn unlinkPrev(link: *Link) ?*Node {
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
            const node = base(link);
            // ABCD -- ACBD.  node is B
            const nodeC: *Node = @field(node, next) orelse return;
            const nodeA: ?*Node = @field(node, prev);
            const nodeD: ?*Node = @field(nodeC, next);

            // B <-> D
            if (nodeD) |D| @field(D, prev) = node;
            @field(node, next) = nodeD;

            // C <-> B
            @field(node, prev) = nodeC;
            @field(nodeC, next) = node;

            // A <-> C
            @field(nodeC, prev) = nodeA;
            if (nodeA) |A| @field(A, next) = nodeC;
        }

        /// Swaps this node's position with the position of `node.prev`.  If it
        /// is `null`, nothing happens.  This can invalidate the first node in a
        /// `List`, this condition can be detected (given otherwise proper use)
        /// if `node.prev` is `null` after the call.
        pub fn swapBackward(link: *Link) void {
            const node = base(link);
            // ABCD -- ACBD.  node is C
            const nodeB: *Node = @field(node, prev) orelse return;
            const nodeD: ?*Node = @field(node, next);
            const nodeA: ?*Node = @field(nodeB, prev);

            // A <-> C
            @field(node, prev) = nodeA;
            if (nodeA) |A| @field(A, next) = node;

            // C <-> B
            @field(node, next) = nodeB;
            @field(nodeB, prev) = node;

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
            const node_next = @field(node, link_field).unlinkNext();

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
            const node_prev = @field(node, link_field).unlinkPrev();
            @field(node, prev) = list.last;
            @field(list.last.?, next) = node;

            @field(list.first.?, prev) = node_prev;
            if (node_prev) |np| @field(np, next) = list.first;
        }

        /// Answers whether the node is in a well-formed double linked
        /// list when following the 'next' pointers.  Perhaps surprisingly,
        /// this answers `true` if `node.next` is `null`.  A `false` answer
        /// means there's a problem with your list.  This is a diagnostic
        /// tool.  If `node.prev` is `null`, this will detect a forward half
        /// cyle as a broken link.
        pub fn inDoubleLinkedListForward(link: *const Link) bool {
            const node = cbase(link);
            var this_node = node;
            var maybe_next = @field(this_node, next);
            while (maybe_next) |next_node| {
                if (@field(next_node, prev) != this_node) return false;
                if (node == next_node) return false;
                this_node = next_node;
                maybe_next = @field(next_node, next);
            }
            return true;
        }

        /// Answers whether the node is in a well-formed double linked
        /// list when following the 'prev' pointers.  Perhaps surprisingly,
        /// this answers `true` if `node.prev` is `null`.  A `false` answer
        /// means there's a problem with your list.  This is a diagnostic
        /// tool.  If `node.next` is `null`, this will detect a backward half
        /// cycle as a broken link.
        pub fn inDoubleLinkedListBackward(link: *const Link) bool {
            const node = cbase(link);
            var this_node = node;
            var maybe_prev = @field(this_node, prev);
            while (maybe_prev) |prev_node| {
                if (@field(prev_node, next) != this_node) return false;
                if (node == prev_node) return false;
                this_node = prev_node;
                maybe_prev = @field(prev_node, prev);
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

        /// List type for doubly-linked lists of the provided data structure.
        /// Create with the `.empty` declaration literal.
        pub const List = struct {
            first: ?*Node,
            last: ?*Node,

            pub const empty: List = .{ .first = null, .last = null };

            /// Inserts `new_node` after `existing_node`, adjusting `list.last` if needed.
            pub fn insertAfter(list: *List, existing_node: *Node, new_node: *Node) void {
                @field(existing_node, link_field).insertAfter(new_node);
                // If new_node is inserted at the end of the list, its 'next' will be null:
                if (@field(new_node, next) == null) {
                    list.last = new_node;
                }
            }

            /// Inserts `new_node` before `existing_node`, adjusting `list.first` if needed.
            pub fn insertBefore(list: *List, existing_node: *Node, new_node: *Node) void {
                @field(existing_node, link_field).insertBefore(new_node);
                // If new_node is inserted at the front of the list, its 'prev' will be null:
                if (@field(new_node, prev) == null) {
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
                const l2_first = list2.first orelse return;
                if (list1.last) |l1_last| {
                    @field(l1_last, next) = list2.first;
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
            /// be found in the `next` direction starting from `from`.  No
            /// `prev` equivalent is provided, simply switch `from` and `to`.
            /// It is valid for `from` to be `list.first`, or for `to` to be
            /// `list.last`; `from` and `to` may not be identical.
            pub fn extractRange(list: *List, from: *Node, to: *Node) List {
                const from_prev = @field(from, link_field).unlinkPrev();
                const to_next = @field(to, link_field).unlinkNext();
                if (from_prev) |now_prev| {
                    if (to_next) |now_next| {
                        // These were both middle nodes
                        @field(now_prev, next) = now_next;
                        @field(now_next, prev) = now_prev;
                    } else {
                        // `to` is assumed to be the last node,
                        // so now, now_prev is the last
                        list.last = now_prev;
                    }
                } else {
                    // `from` was the first.  We need to know if
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

            /// Splices `list2` `next` to the parameter `node`.  When this
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

            /// Splices `list2` `prev` to the parameter `node`.  When this
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

            /// Insert a new node at the end of the list.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn append(list: *List, new_node: *Node) void {
                if (list.last) |last| {
                    // Insert after last.
                    list.insertAfter(last, new_node);
                } else {
                    // Empty list.
                    list.prepend(new_node);
                }
            }

            /// Insert a new node at the beginning of the list.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn prepend(list: *List, new_node: *Node) void {
                if (list.first) |first| {
                    // Insert before first.
                    list.insertBefore(first, new_node);
                } else {
                    // Empty list.
                    list.first = new_node;
                    list.last = new_node;
                    @field(new_node, prev) = null;
                    @field(new_node, next) = null;
                }
            }

            /// Remove a node from the list.  Assumes this node belongs to
            /// this list.
            ///
            /// Arguments:
            ///     node: Pointer to the node to be removed.
            pub fn remove(list: *List, node: *Node) void {
                switch (@field(node, link_field).positionInList()) {
                    .first => {
                        list.first = @field(node, link_field).unlinkNext();
                    },
                    .last => {
                        list.last = @field(node, link_field).unlinkPrev();
                    },
                    .middle => @field(node, link_field).removeSelfFromList(),
                    .solo => {},
                }
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

            /// Answers whether the list is empty.
            pub inline fn isEmpty(list: List) bool {
                return list.first == null and list.last == null;
            }
        };
    };
}

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

test "Sorted singly-linked list" {
    const Sorted = struct {
        val: u32,
        next_val: ?*S = null,
        mixer: Link = .{},

        pub const empty: S = .{ .val = undefined };

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
        try expectEqual(9, rsorted.mixer.countChildren() + 1);
        try expectEqual(rsorted, still_rsorted);
        try expect(still_rsorted.mixer.isOrderedDescending());
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
    list.insertBefore(&five, &four); // {1, 2, 4, 5}
    list.insertAfter(&two, &three); // {1, 2, 3, 4, 5}

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
    alice.the_link.insertAfter(&bob);
    try testing.expectEqual(&bob, alice.next.?);
    try testing.expectEqual(null, alice.prev);

    bob.the_link.insertAfter(&charlie);
    try testing.expectEqual(&charlie, bob.next.?);
    try testing.expectEqual(null, alice.prev);
    try testing.expectEqual(&bob, alice.next.?);

    charlie.the_link.insertAfter(&alice);
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
    glen.the_link.insertBefore(&frank);
    frank.the_link.insertBefore(&ethel);
    ethel.the_link.insertBefore(&glen);

    try testing.expect(ethel.the_link.inCycleBackward());
    try testing.expect(ethel.the_link.inCycleForward());
    try testing.expect(frank.the_link.inCycleBackward());
    try testing.expect(frank.the_link.inCycleForward());
    try testing.expect(glen.the_link.inCycleBackward());
    try testing.expect(glen.the_link.inCycleForward());
}

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

//! Zelda: a Link to the List
//!
//! This library generates linked-list functions for a provided type, given
//! the name of the field or fields which are linkable.
//!

const std = @import("std");

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
pub fn aLinkToThePast(T: type, comptime next: anytype) type {
    return singlyLinkedList(T, next);
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
pub fn aLinkBetweenWorlds(T: type, comptime next: anytype, comptime prev: anytype) type {
    return doublyLinkedList(T, next, prev);
}

/// Provides a container with functions implementing singly-linkèd node
/// behavior for the type, and a SinglyLinkedList type for making use
/// of such lists.  `next_name` must be a string or enum literal which
/// represents a field of type `?*Node` on Node itself.
///
/// It is legal to call this several times with different field names.
/// You will however need to deal with the name collisions manually.
pub fn singlyLinkedList(Node: type, comptime next_name: anytype) type {
    // String-ify potential enum literal:
    const next: []const u8 = if (@typeInfo(@TypeOf(next_name)) == .enum_literal)
        @tagName(next_name)
    else // If it coerces, it works:
        next_name;

    verifyFieldType(Node, next);

    return struct {
        //| Node functions

        pub const ThisNode = @This(); // Needed for calling declarations in SinglyLinkedList

        /// Insert the argument node after the receiver node.
        pub fn insertAfter(node: *Node, new_node: *Node) void {
            @field(new_node, next) = @field(node, next);
            @field(node, next) = new_node;
        }

        /// Remove the node after the one provided, returning it. Node will be
        /// linked to the node after that, if any.  If a node is returned, its
        /// next field will be null.
        pub fn removeNext(node: *Node) ?*Node {
            const next_node = @field(node, next) orelse return null;
            @field(node, next) = @field(next_node, next);
            @field(next_node, next) = null;
            return next_node;
        }

        /// Swaps the node's position with the Node at `next`.  If no such
        /// Node exists, nothing happens, and `null` is returned.  The
        /// now-previous node is returned, in case it might be useful, as,
        /// for example, if `node` is `.first` in a SinglyLinkedList, and
        /// must therefore be replaced as head.
        pub fn swap(node: *Node) ?*Node {
            const next_node = @field(node, next) orelse return null;
            @field(node, next) = @field(next_node, next);
            @field(next_node, next) = node;
            return next_node;
        }

        /// Iterate over the singly-linked list from this node, until the final
        /// node is found.
        ///
        /// This operation is O(N). Instead of calling this function, consider
        /// using a different data structure.
        pub fn findLast(node: *Node) *Node {
            var it = node;
            while (true) {
                it = @field(it, next) orelse return it;
            }
        }

        /// Iterate over each next node, returning the count of all nodes except
        /// the starting one.
        ///
        /// This operation is O(N). Instead of calling this function, consider
        /// using a different data structure.
        pub fn countChildren(node: *const Node) usize {
            var count: usize = 0;
            var it: ?*const Node = @field(node, next);
            while (it) |n| : (it = @field(n, next)) {
                count += 1;
            }
            return count;
        }

        /// Reverse the list starting from this node in-place.
        ///
        /// This operation is O(N). Instead of calling this function, consider
        /// using a different data structure.
        pub fn reverse(indirect: *?*Node) void {
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

        //| Singly Linked List container type

        pub const SinglyLinkedList = struct {
            first: ?*Node,

            pub const empty: SinglyLinkedList = .{ .first = null };

            pub fn init(first: ?*Node) SinglyLinkedList {
                return .{ .first = first };
            }

            /// Prepend `new_node` as the first link in the list.
            pub fn prepend(list: *SinglyLinkedList, new_node: *Node) void {
                @field(new_node, next) = list.first;
                list.first = new_node;
            }

            /// This is not a place of honor.  No esteemed deed is commemorated
            /// here.  We thought we were a powerful culture.  What is here is
            /// repulsive to us.  Repeated use of append is O(n^2).  Contemplate
            /// this on the tree of woe.
            pub fn append(list: *SinglyLinkedList, new_node: *Node) void {
                if (list.first) |f| {
                    var last = ThisNode.findLast(f);
                    @field(last, next) = new_node;
                } else {
                    list.first = new_node;
                }
            }

            /// Find and remove `node` from the list.  This compares pointers,
            /// not values.  It is valid  to 'remove' a node which is not in
            /// the list, which does not make it a good idea.  If the node is
            /// found in the list, the 'next' field will be `null`, if it is
            /// not, the field will not change.
            pub fn remove(list: *SinglyLinkedList, node: *Node) void {
                if (list.first == node) {
                    list.first = @field(node, next);
                    @field(node, next) = null;
                } else {
                    var current_elm = list.first.?;
                    find: while (@field(current_elm, next)) |next_elm| {
                        if (next_elm == node) {
                            @field(current_elm, next) = @field(node, next);
                            @field(node, next) = null;
                            break :find;
                        } else {
                            current_elm = next_elm;
                        }
                    }
                }
            }

            /// Remove and return the first node in the list, should one be
            /// present.
            pub fn popFirst(list: *SinglyLinkedList) ?*Node {
                const first = list.first orelse return null;
                list.first = @field(first, next);
                @field(first, next) = null;
                return first;
            }

            /// Iterate over all nodes, returning the count.
            ///
            /// This operation is O(N). Consider tracking the length separately rather than
            /// computing it.
            pub fn len(list: SinglyLinkedList) usize {
                if (list.first) |n| {
                    return 1 + ThisNode.countChildren(n);
                } else {
                    return 0;
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

/// Returns a container type with methods for working with the DNode type as nodes in a
/// doubly-linked list, using the field names `next_name` and `prev_name`.  The container also
/// contains a `DoublyLinkedList` type specialized to this type of node.  It is valid to call
/// this for multiple _disjoint_ pairs of fields, however you will need to deal with name
/// collisions manually in the original struct.
pub fn doublyLinkedList(DNode: type, comptime next_name: anytype, comptime prev_name: anytype) type {
    // String-ify potential enum literal:
    const next: []const u8 = if (@typeInfo(@TypeOf(next_name)) == .enum_literal)
        @tagName(next_name)
    else // If it coerces, it works:
        next_name;

    const prev: []const u8 = if (@typeInfo(@TypeOf(prev_name)) == .enum_literal)
        @tagName(prev_name)
    else // If it coerces, it works:
        prev_name;

    verifyFieldType(DNode, next);
    verifyFieldType(DNode, prev);

    //| Stdlib provides no functions for the Node type itself, for reasons which are unclear.
    //| We will take the approach of providing primitives for Operations on Nodes, suitable
    //| for ad-hoc use without employing the DoublyLinkedList type.

    return struct {
        /// Insert the receiver node after the parameter node.
        pub fn insertAfter(node: *DNode, new_node: *DNode) void {
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
        pub fn insertBefore(node: *DNode, new_node: *DNode) void {
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
        pub fn positionInList(node: *DNode) DoubleLinkedListPosition {
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

        /// Remove the receiver node from the linked list.  Use carefully!
        /// This can strand memory and lead to a leak.  Prefer to use the
        /// function `remove` on the DoublyLinkedList type.
        /// If `node.positionInList() == .middle`, this will not strand
        /// either end of a properly-constituted list.
        pub fn removeSelfFromList(node: *DNode) void {
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
        pub fn unlinkNext(node: *DNode) ?*DNode {
            const this_next = @field(node, next) orelse return null;
            @field(this_next, prev) = null;
            @field(node, next) = null;
            return this_next;
        }

        /// Unlink from the previous structure, if any.  Returns the unlinked
        /// struct, or null.
        pub fn unlinkPrev(node: *DNode) ?*DNode {
            const this_prev = @field(node, prev) orelse return null;
            @field(this_prev, next) = null;
            @field(node, prev) = null;
            return this_prev;
        }

        /// Swaps this node's position with the position of `node.next`.  If
        /// it is `null`, nothing happens.  This can invalidate the last node
        /// in a DoublyLinkedList, this condition can be detected (given
        /// otherwise proper use) if `node.next` is `null` after the call.
        pub fn swapForward(node: *DNode) void {
            // ABCD -- ACBD.  node is B
            const nodeC: *DNode = @field(node, next) orelse return;
            const nodeA: ?*DNode = @field(node, prev);
            const nodeD: ?*DNode = @field(nodeC, next);

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

        /// Swaps this node's position with the position of `node.prev`.  If
        /// it is `null`, nothing happens.  This can invalidate the first node
        /// in a DoublyLinkedList, this condition can be detected (given
        /// otherwise proper use) if `node.prev` is `null` after the call.
        pub fn swapBackward(node: *DNode) void {
            // ABCD -- ACBD.  node is C
            const nodeB: *DNode = @field(node, prev) orelse return;
            const nodeD: ?*DNode = @field(node, next);
            const nodeA: ?*DNode = @field(nodeB, prev);

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
        pub fn spliceForward(node: *DNode, list: *DoublyLinkedList) void {
            const node_next = ThisNode.unlinkNext(node);

            @field(node, next) = list.first;
            @field(list.first.?, prev) = node;

            @field(list.last.?, next) = node_next;
            if (node_next) |nn| @field(nn, prev) = list.last;
        }

        /// Slices the list in the `prev` direction of the receiver.  The list is
        /// not cleared and will be in an invalid state.  It is checked illegal
        /// behavior for `list` to be empty.  Prefer to use `spliceBackwardOf` on
        /// the list containing the node.
        pub fn spliceBackward(node: *DNode, list: *DoublyLinkedList) void {
            const node_prev = ThisNode.unlinkPrev(node);
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
        pub fn inDoubleLinkedListForward(node: *DNode) bool {
            var this_node = node;
            var maybe_next = @field(this_node, next);
            while (maybe_next) |next_node| {
                if (@field(next_node, prev) != this_node) return false;
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
        pub fn inDoubleLinkedListBackward(node: *DNode) bool {
            var this_node = node;
            var maybe_prev = @field(this_node, prev);
            while (maybe_prev) |prev_node| {
                if (@field(prev_node, next) != this_node) return false;
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
        pub fn inCycleForward(node: *DNode) bool {
            var tortoise: *DNode = node;
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
        pub fn inCycleBackward(node: *DNode) bool {
            var tortoise: *DNode = node;
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

        /// Multiple intrusive lists being possible, we always call functions
        /// from the type, not as members.
        const ThisNode = @This();

        /// DoublyLinkedList type for provided data structure.  Create with the `.empty`
        /// declaration literal.
        pub const DoublyLinkedList = struct {
            first: ?*DNode,
            last: ?*DNode,

            pub const empty: DoublyLinkedList = .{ .first = null, .last = null };

            /// Inserts `new_node` after `existing_node`, adjusting `list.last` if needed.
            pub fn insertAfter(list: *DoublyLinkedList, existing_node: *DNode, new_node: *DNode) void {
                ThisNode.insertAfter(existing_node, new_node);
                // If new_node is inserted at the end of the list, its 'next' will be null:
                if (@field(new_node, next) == null) {
                    list.last = new_node;
                }
            }

            /// Inserts `new_node` before `existing_node`, adjusting `list.first` if needed.
            pub fn insertBefore(list: *DoublyLinkedList, existing_node: *DNode, new_node: *DNode) void {
                ThisNode.insertBefore(existing_node, new_node);
                // If new_node is inserted at the front of the list, its 'prev' will be null:
                if (@field(new_node, prev) == null) {
                    list.first = new_node;
                }
            }

            /// Concatenate list2 onto the end of list1, removing all entries from the former.
            ///
            /// Arguments:
            ///     list1: the list to concatenate onto
            ///     list2: the list to be concatenated
            pub fn concatByMoving(list1: *DoublyLinkedList, list2: *DoublyLinkedList) void {
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

            /// Extract the range from `from` to `to` as a new linked list, healing the gap in the list
            /// thereby created.  Assumes that `from` and `to` are valid members of `list`, and that `to`
            /// may be found in the `next` direction starting from `from`.  No `prev` equivalent is provided,
            /// simply switch `from` and `to`.  It is valid for `from` to be `list.first`, or for `to` to be
            /// `list.last`; `from` and `to` may not be identical.
            pub fn extractRange(list: *DoublyLinkedList, from: *DNode, to: *DNode) DoublyLinkedList {
                const from_prev = ThisNode.unlinkPrev(from);
                const to_next = ThisNode.unlinkNext(to);
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

            /// Splices `list2` `next` to the parameter `node`.  When this function returns, `list2`
            /// will be empty.  This is valid to call when `node` is either the first or the last node
            /// on the receiver list, but if this is known to be the case, prefer `concatByMoving`.  It is
            /// assumed that `list` has contents (at least `node`), and checked illegal behavior if `list2`
            /// does not.
            pub fn spliceForwardOf(list: *DoublyLinkedList, node: *DNode, list2: *DoublyLinkedList) void {
                ThisNode.spliceForward(node, list2);
                if (list.last == node) {
                    list.last = list2.last;
                }
                list2.first = null;
                list2.last = null;
            }

            /// Splices `list2` `prev` to the parameter `node`.  When this function returns, `list2`
            /// will be empty.  This is valid to call when `node` is either the first or the last node
            /// on the receiver list, but if this is known to be the case, prefer `concatByMoving`.  It is
            /// assumed that `list` has contents (at least `node`), and checked illegal behavior if `list2`
            /// does not.
            pub fn spliceBackwardOf(list: *DoublyLinkedList, node: *DNode, list2: *DoublyLinkedList) void {
                ThisNode.spliceBackward(node, list2);
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
            pub fn append(list: *DoublyLinkedList, new_node: *DNode) void {
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
            pub fn prepend(list: *DoublyLinkedList, new_node: *DNode) void {
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
            pub fn remove(list: *DoublyLinkedList, node: *DNode) void {
                switch (ThisNode.positionInList(node)) {
                    .first => {
                        list.first = ThisNode.unlinkNext(node);
                    },
                    .last => {
                        list.last = ThisNode.unlinkPrev(node);
                    },
                    .middle => ThisNode.removeSelfFromList(node),
                    .solo => {},
                }
            }

            /// Remove and return the last node in the list.
            ///
            /// Returns:
            ///     A pointer to the last node in the list.
            pub fn pop(list: *DoublyLinkedList) ?*DNode {
                const last = list.last orelse return null;
                list.remove(last);
                return last;
            }

            /// Remove and return the first node in the list.
            ///
            /// Returns:
            ///     A pointer to the first node in the list.
            pub fn popFirst(list: *DoublyLinkedList) ?*DNode {
                const first = list.first orelse return null;
                list.remove(first);
                return first;
            }

            /// Iterate over all nodes, returning the count.
            ///
            /// This operation is O(N). Consider tracking the length separately rather than
            /// computing it.
            pub fn len(list: DoublyLinkedList) usize {
                var count: usize = 0;
                var it: ?*const DNode = list.first;
                while (it) |n| : (it = @field(n, next)) count += 1;
                return count;
            }

            /// Answers whether the list is empty.
            pub inline fn isEmpty(list: DoublyLinkedList) bool {
                return list.first == null and list.last == null;
            }
        };
    };
}

// Satisfy ourselves that the type fulfills the necessary contract for the field.
fn verifyFieldType(T: type, comptime field_name: []const u8) void {
    if (!@hasField(T, field_name)) {
        @compileError("The field name provided is not valid for the type");
    }
    const f_info = @typeInfo(@FieldType(T, field_name));
    switch (f_info) {
        .optional => |o| {
            const c_info = @typeInfo(o.child);
            switch (c_info) {
                .pointer => |p| {
                    if (p.child != T) {
                        @compileError("Optional pointer field does not point to the type");
                    }
                    if (p.is_const) {
                        @compileError("The pointer field's type is const");
                    }
                },
                else => @compileError("Optional field type is not a pointer"),
            }
        },
        else => @compileError("Field type is not optional (?)"),
    }
}

// Tests

const testing = std.testing;
const expectEqual = testing.expectEqual;

const Hyrule = struct {
    data: usize,
    next_member: ?*Hyrule = null,

    pub fn init(data: usize) Hyrule {
        return .{ .data = data };
    }

    pub const linkedIn = aLinkToThePast(Hyrule, .next_member);
    pub const swap = linkedIn.swap;
    pub const removeNext = linkedIn.removeNext;
    pub const insertAfter = linkedIn.insertAfter;
};

test Hyrule {
    var this: Hyrule = .init(23);
    var that: Hyrule = .init(42);
    this.insertAfter(&that);
    try expectEqual(this.next_member.?, &that);
    _ = this.swap();
    try expectEqual(that.next_member.?, &this);
    _ = that.swap();
    const that_again = this.removeNext().?;
    try expectEqual(&that, that_again);
}

test "A Link to the Past" {
    const L = struct {
        data: u32,
        node: ?*@This() = null,

        pub const linkedIn = aLinkToThePast(@This(), .node);
        pub const SinglyLinkedList = linkedIn.SinglyLinkedList;
        pub const insertAfter = linkedIn.insertAfter;
        pub const reverse = linkedIn.reverse;
        pub const removeNext = linkedIn.removeNext;
    };

    var list: L.SinglyLinkedList = .empty;

    try testing.expect(list.len() == 0);

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list.prepend(&two); // {2}
    two.insertAfter(&five); // {2, 5}
    list.prepend(&one); // {1, 2, 5}
    two.insertAfter(&three); // {1, 2, 3, 5}
    three.insertAfter(&four); // {1, 2, 3, 4, 5}

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
    _ = two.removeNext(); // {2, 4}

    try testing.expect(list.first.?.data == 2);
    try testing.expect(list.first.?.node.?.data == 4);
    try testing.expect(list.first.?.node.?.node == null);

    L.reverse(&list.first);

    try testing.expect(list.first.?.data == 4);
    try testing.expect(list.first.?.node.?.data == 2);
    try testing.expect(list.first.?.node.?.node == null);
}

test "A Link Between Worlds" {
    const L = struct {
        data: u32,
        forward: ?*@This() = null,
        backward: ?*@This() = null,

        pub const linkedIn = aLinkBetweenWorlds(@This(), "forward", .backward);

        pub const DoublyLinkedList = linkedIn.DoublyLinkedList;
        pub const insertBefore = linkedIn.insertBefore;
        pub const insertAfter = linkedIn.insertAfter;
        pub const swapForward = linkedIn.swapForward;
        pub const swapBackward = linkedIn.swapBackward;
        pub const inDoubleLinkedListForward = linkedIn.inDoubleLinkedListForward;
        pub const inDoubleLinkedListBackward = linkedIn.inDoubleLinkedListBackward;
        pub const inCycleForward = linkedIn.inCycleForward;
        pub const inCycleBackward = linkedIn.inCycleBackward;
    };
    var list: L.DoublyLinkedList = .empty;

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

    try testing.expect(one.inDoubleLinkedListForward());
    try testing.expect(five.inDoubleLinkedListBackward());

    // Swap

    try testing.expectEqual(2, three.backward.?.data);

    three.swapForward();
    try testing.expectEqual(4, three.backward.?.data);
    try testing.expectEqual(5, three.forward.?.data);
    try testing.expect(one.inDoubleLinkedListForward());
    try testing.expect(five.inDoubleLinkedListBackward());

    three.swapBackward();
    try testing.expectEqual(4, three.forward.?.data);
    try testing.expectEqual(2, three.backward.?.data);
    try testing.expect(one.inDoubleLinkedListForward());
    try testing.expect(five.inDoubleLinkedListBackward());

    four.swapForward();
    try testing.expectEqual(5, three.forward.?.data);
    try testing.expectEqual(null, four.forward);
    try testing.expect(one.inDoubleLinkedListForward());
    try testing.expect(five.inDoubleLinkedListBackward());

    four.swapBackward();
    try testing.expectEqual(5, four.forward.?.data);
    try testing.expectEqual(null, five.forward);
    try testing.expect(one.inDoubleLinkedListForward());
    try testing.expect(five.inDoubleLinkedListBackward());

    try testing.expect(!one.inCycleForward());
    try testing.expect(!five.inCycleBackward());

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

        pub const linkedIn = aLinkBetweenWorlds(@This(), .next, "prev");
        pub const DoublyLinkedList = linkedIn.DoublyLinkedList;
        pub const insertBefore = linkedIn.insertBefore;
        pub const insertAfter = linkedIn.insertAfter;
        pub const swapForward = linkedIn.swapForward;
        pub const swapBackward = linkedIn.swapBackward;
        pub const inDoubleLinkedListForward = linkedIn.inDoubleLinkedListForward;
        pub const inDoubleLinkedListBackward = linkedIn.inDoubleLinkedListBackward;
        pub const inCycleForward = linkedIn.inCycleForward;
        pub const inCycleBackward = linkedIn.inCycleBackward;
    };

    var list1: L.DoublyLinkedList = .empty;
    var list2: L.DoublyLinkedList = .empty;

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

        pub const linkedIn = doublyLinkedList(@This(), .next, .prev);

        pub const DoublyLinkedList = linkedIn.DoublyLinkedList;
        pub const insertBefore = linkedIn.insertBefore;
        pub const insertAfter = linkedIn.insertAfter;
        pub const swapForward = linkedIn.swapForward;
        pub const swapBackward = linkedIn.swapBackward;
        pub const inDoubleLinkedListForward = linkedIn.inDoubleLinkedListForward;
        pub const inDoubleLinkedListBackward = linkedIn.inDoubleLinkedListBackward;
        pub const inCycleForward = linkedIn.inCycleForward;
        pub const inCycleBackward = linkedIn.inCycleBackward;
    };

    var alice: Kid = .{};
    var bob: Kid = .{};
    var charlie: Kid = .{};
    var dan: Kid = .{};
    alice.insertAfter(&bob);
    try testing.expectEqual(&bob, alice.next.?);
    try testing.expectEqual(null, alice.prev);

    bob.insertAfter(&charlie);
    try testing.expectEqual(&charlie, bob.next.?);
    try testing.expectEqual(null, alice.prev);
    try testing.expectEqual(&bob, alice.next.?);

    charlie.insertAfter(&alice);
    try testing.expectEqual(&alice, charlie.next.?);
    try testing.expectEqual(&bob, charlie.prev.?);
    try testing.expectEqual(&charlie, alice.prev.?);

    try testing.expectEqual(&bob, alice.next.?);
    try testing.expectEqual(&charlie, bob.next.?);
    try testing.expectEqual(&alice, charlie.next.?);

    try testing.expect(charlie.inCycleBackward());
    try testing.expect(charlie.inCycleForward());
    try testing.expect(alice.inCycleBackward());
    try testing.expect(alice.inCycleForward());
    try testing.expect(bob.inCycleBackward());
    try testing.expect(bob.inCycleForward());

    dan.next = &bob;
    try testing.expect(dan.inCycleForward());
    try testing.expect(!dan.inCycleBackward());

    var ethel: Kid = .{};
    var frank: Kid = .{};
    var glen: Kid = .{};
    glen.insertBefore(&frank);
    frank.insertBefore(&ethel);
    ethel.insertBefore(&glen);

    try testing.expect(ethel.inCycleBackward());
    try testing.expect(ethel.inCycleForward());
    try testing.expect(frank.inCycleBackward());
    try testing.expect(frank.inCycleForward());
    try testing.expect(glen.inCycleBackward());
    try testing.expect(glen.inCycleForward());
}

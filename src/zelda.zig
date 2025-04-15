//! Zelda: a Link to the List
//!
//! This library generates linked-list functions for a provided type, given
//! the name of the field or fields which are linkable.
//!

const std = @import("std");

pub fn aLinkToThePast(T: type, comptime next: anytype) type {
    return singleLink(T, next);
}

pub fn singleLink(Node: type, comptime next_name: anytype) type {
    // String-ify potential enum literal:
    const next: []const u8 = if (@typeInfo(@TypeOf(next_name)) == .enum_literal)
        @tagName(next_name)
    else // If it coerces, it works:
        next_name;

    verifyFieldType(Node, next);

    return struct {
        //| Node functions

        /// Insert the argument node after the receiver node.
        pub fn insertAfter(node: *Node, new_node: *Node) void {
            @field(new_node, next) = @field(node, next);
            @field(node, next) = new_node;
        }

        /// Remove the node after the one provided, returning it.
        pub fn removeNext(node: *Node) ?*Node {
            const next_node = @field(node, next) orelse return null;
            @field(node, next) = @field(next_node, next);
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

            /// Prepend `new_node` as the first link in the list.
            pub fn prepend(list: *SinglyLinkedList, new_node: *Node) void {
                @field(new_node, next) = list.first;
                list.first = new_node;
            }

            /// Find and remove `node` from the list.  This compares pointers,
            /// not values.
            pub fn remove(list: *SinglyLinkedList, node: *Node) void {
                if (list.first == node) {
                    list.first = @field(node, next);
                } else {
                    var current_elm = list.first.?;
                    while (@field(current_elm, next) != node) {
                        current_elm = @field(current_elm, next).?;
                    }
                    @field(current_elm, next) = @field(node, next);
                }
            }

            /// Remove and return the first node in the list.
            pub fn popFirst(list: *SinglyLinkedList) ?*Node {
                const first = list.first orelse return null;
                list.first = @field(first, next);
                return first;
            }

            /// Iterate over all nodes, returning the count.
            ///
            /// This operation is O(N). Consider tracking the length separately rather than
            /// computing it.
            pub fn len(list: SinglyLinkedList) usize {
                if (list.first) |n| {
                    return 1 + n.countChildren();
                } else {
                    return 0;
                }
            }
        };
    };
}

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
                        @compileError("The pointer type is const");
                    }
                },
                else => @compileError("Optional field type is not a pointer"),
            }
        },
        else => @compileError("Field is not an optional type"),
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

    pub usingnamespace aLinkToThePast(Hyrule, .next_member);
};

test "links" {
    var this: Hyrule = .init(23);
    var that: Hyrule = .init(42);
    this.insertAfter(&that);
    try expectEqual(this.next_member.?, &that);
    const that_again = this.removeNext().?;
    try expectEqual(&that, that_again);
}

test "basics" {
    const L = struct {
        data: u32,
        node: ?*@This() = null,

        pub usingnamespace aLinkToThePast(@This(), .node);
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

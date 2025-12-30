# Zelda: Type Safe Intrusive Linked Lists

Zig recently (April 2025) introduced a new interface for
[SinglyLinkedList][sll] and [DoublyLinkedList][dll]).  Prior to the
change, these were 'textbook' linked lists, with a data pointer and one
or two link pointers.

As of the change, both are now [intrusive][ilist], meaning that the
link or links are now fields on a parent struct.  As discussed in that
article, and further discussed on [The Orange Website][bagofdicks],
these are usually what you want.

The versions found in the standard library are capable, if someone
bare, but have one notable disadvantage: they aren't type safe.  A
[Node][gnowde] is embedded in full genericity, and `@fieldParentPtr`
is used to retrieve the root address of the struct.  Or memory at the
expected location, but not in the expected format, if two link-bearing
lists get crosslinked somehow.

I thought perhaps this could be improved upon, so I did so, then we lost
`usingnamespace`, which took the shine off a bit.  Then I did it again,
and here we are.

[sll]: https://ziglang.org/documentation/0.15.2/std/#std.SinglyLinkedList
[dll]: https://ziglang.org/documentation/master/std/#std.DoublyLinkedList
[ilist]: https://www.openmymind.net/Zigs-New-LinkedList-API/
[bagofdicks]: https://news.ycombinator.com/item?id=43679707
[gnowde]: https://ziglang.org/documentation/0.15.2/std/#std.DoublyLinkedList.Node

## Type Safe Intrusion Without @fieldParentPtr

To use `zelda`, presuming you've added it to the build system, do the following:

```zig
// It's dangerous to go alone! Take this!
const zelda = @import("zelda");

const Monster = struct {
    kind: MonsterKind,
    mana: u16,
    health: u16,
    // ...
    next: ?*@This() = null, // Probably a good idea
    previous: ?*@This() = null,
    link: Link = .{}, // What's a Link?

    // This is a Link:
    pub const Link = zelda.aLinkBetweenWorlds(@This();
    pub const List = Link.List;

    // That's the magic version, we'll peek behind the curtain forthwith.

    // Not-linked-list declarations go here
};
```

This makes various linked-list operations available by calling,
for instance, `monster.link.unlinkForward()`.  This, too, uses
`@fieldParentPtr`, but with type safety: each `Link` is specialized to
the type it belongs to, and comptime wizardry is used to do the field
parent pointer-ing within calls off the zero-width `.link` field.  This
is, adequate.  Perhaps not elegant, but eloquent enough.

Say you prefer, as indeed you might, a _singly_ linked list? We have that as well!

> It's yours, my friend, as long as you have enough rupees.

```zig
const Chunk64 = struct {
    data: [64]u8 = undefined;
    next_free: ?*@This() = null,
    call_me_whatever: Link = .{}, // zelda don't care

    pub const Link = zelda.aLinkToThePast(@This());
    pub const List = Link.List;

    // What if you have more than one link though?  For that,
    // we have zelda.singlyLinkedList.
};
```

Now your `Chunk64` will do single-linked node things, and has
`Chunk64.List` to manage your freelist.

These types are a proper superset of the functionality given by the
stdlib types, and pass all the same tests, after light porting which
primarily consists of removing code.  They exhibit somewhat different
behavior for properties not tested in stdlib, for reasons I'll get into.

## The Shirt and Tie API

For maximum control, and incrementally less fun, we have

### zelda.singlyLinkedList(T: type, next: anytype, m_orderFn: ?[]const u8)

The type, the name of the link field, and a name for an ordering function,
if you care to provide one.  `aLinkToThePast` figures that stuff out for you,
but you have to name your function `zeldaOrderFn`.

It should return a `zelda.Order`, this is like [`std.math.Order`][smo] but
it generates good machine code.  Zelda doesn't check this so you can
use the other one, or something even harder to optimize, so long as it
returns `.lt`, `.eq`, and `.gt`, in a manner which leaves you happy with
the resulting stable ordering.

[smo]: https://ziglang.org/documentation/0.15.2/std/#std.math.Order

### zelda.doublyLinkedList(T: type, next: anytype, prev: anytype, m_orderFn: ?[]const u8)

Same deal.

You are encouraged to peruse the source, or build the docs, in order to
pick up on what all these lists have built in.

## Cool, How'd You Do It?

```sh
➜  rg -F --count-matches '@field' -- src/zelda.zig
95
```
This number might fairly be expected to increase.

## Advantages (Our Last Line of Defense Will Be Link)

Strictly, these are "tradeoffs", but ones I happen to think will be
advantageous more often than not.

In the stdlib vision of linking, the links are fully generic.  They
have a type, it's up to the user to keep an eye on which kind of list
it makes sense to put a given Node onto. `zelda` makes this a compiler
problem instead of a you problem.

The pointers also point (or do not) to the data itself, not to a field
in the data.  Well, they did; I have no idea what 'offset' a zero-width
field live at, and I refuse to find out.  There is no need to calculate
the offset of the head of the structure using `@fieldParentPointer` (in
user code that is), and therefore, no opportunity to evince unchecked
illegal behavior due to a mistake in calculating that offset.  There are
plans to make this sort of thing _checked_ illegal behavior, which I
welcome, but I prefer compile time errors to their run time cousins.

The _possible_ disadvantage is that these are _not_ generic, and
therefore it is likely, but not guaranteed, that the compiler will
specialize the various functions provided for each type which is sent to
Hyrule to rescue the Princess.  A highly constrained embedded systems
program might prefer to guarantee once-only compilation by using a
generic type, and happily pay the bookkeeping cost and error risk of
tracking types through the code to ensure proper behavior.

My suspicion is that if the Node field or fields are at the same offset
for several structs, LLVM will specialize several times and then merge
them.  At present Zig lays out structs early enough that the later parts
of the pipeline cannot inform that process of an opportunity to put
fields at the same offset thereby saving code, although this is not
inevitable.  This can be achieved durably with `extern` and on a fragile
basis by studying how struct layout works and tweaking the code, I would
check if LLVM can actually eliminate dupes before going to that kind of
trouble.

Regardless, many of us are happy to take the risk of more code instead
of the risk of illegal memory access at runtime.  Zelda makes that
tradeoff.

#### You Mentioned Some Differences?

Ah. Right.  In stdlib, links are not made `null` when removed, and they
_are_ made `null` when added in certain ways.

In `zelda`, we remove links by a) removing the link from the list and
b) removing the list from the link.  In consequence, unexpected things
might happen if a link which we expect to be `null` (as it would be, as
a consequence of using the provided API), is not `null`.

We do this for a simple reason: fear.

### Alright! Let's Copypasta This Bad Boy!

Have at it:
```sh
zig fetch --save https://github.com/mnemnion/zelda/archive/refs/tags/v0.2.0.tar.gz
```

## Roadmap

I'm probably going to add some stuff.

That and test more.


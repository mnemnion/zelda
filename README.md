# Zelda: Type Safe Intrusive Linked Lists

Zelda is a Zig mixin library for intrusive linked lists.  A linked list
is 'intrusive' when the pointer or pointers which comprise the list
are fields directly on the data structure, rather than the "textbook"
approach of pairing a pointer to the data with a pointer or pointers
comprising the list.  Since intrusive lists take up less memory, and
need fewer pointer chases to make use of them, they are nearly always
what you want.

The Zig standard library already provides [SinglyLinkedList][sll]
and [DoublyLinkedList][dll], which, since `0.14`, are implemented
intrusively.  These are implemented as concrete types, meaning every
list and every `Node` is of one single type.  User code is expected to
ensure that everything linked into the list is of a common type, and
use the `@fieldParentPtr` builtin to retrieve the base address of the
intruded structs, or at least, what should be the base address.

Zelda is an alternative to this: given an appropriately-structured
struct type, endow it with a rich collection of list operations,
and construct a list type unique to that struct.  Originally taking
advantage of `usingnamespace`, this is no longer possible, and was
always a rather blunt instrument.

Now, we use the zero-width field hack.  Ungainly, perhaps, but
effective, precise, and at no runtime cost relative to adding methods to
the struct directly.

The lists in the standard library embody a minimalist philosophy, those
in Zelda a maximalist one.  On top of a kitchen-sink collection of every
list operation which seemed plausibly useful, when given an ordering
function, Zelda offers ordered operations on lists as well.

[sll]: https://ziglang.org/documentation/0.15.2/std/#std.SinglyLinkedList
[dll]: https://ziglang.org/documentation/master/std/#std.DoublyLinkedList

## Link's Awakening

To use `zelda`, presuming you've added it to the build system, do the
following:

```zig
// It's dangerous to go alone! Take this!
const zelda = @import("zelda");

const Monster = struct {
    kind: MonsterKind,
    mana: u16,
    health: u16,
    // ...
    next: ?*@This() = null,
    previous: ?*@This() = null,
    link: Link = .{}, // What's a Link?

    // This is a Link:
    pub const Link = zelda.aLinkBetweenWorlds(@This());
    // This is a (doubly) linked list
    pub const List = Link.List;

    // That's the magic version, we'll peek behind the curtain forthwith.
```

This makes various linked-list operations available by calling, for
instance, `monster.link.unlinkForward()`.  The type and field names, of
course, are entirely up to you.  This, too, uses `@fieldParentPtr`, but
with type safety: each `Link` is specialized to the type it belongs to,
and comptime wizardry is used to do the field parent pointer-ing within
calls off the zero-width `.link` field.  This is, adequate.  Perhaps not
elegant, but eloquent enough.  It does simplify the organization of a
struct bearing more than one list structure, which does occur from time
to time.

Using `aLinkBetweenWorlds`, Zelda will infer the structure and
capabilities of your list.  The first `?*T` field encountered will be
considered "forward", the second "backward".  If it sees a declaration
`zeldaOrderFn`, it will try to use this as an ordering function to
provide numerous facilities, which, if the declaration is appropriate,
will succeed.

If this specific organization is not suitable, or should you find
yourself in a less than whimsical mood, these may be specified manually
using `zelda.doublyLinkedList`.  Currently, any ordering function must
be supplied as a string naming a public declaration, I may make it
possible to provide this as a function at some later point.

There is nothing stopping you from creating several of these exotic
zero-width fields, to handle multiple pairs of links or, more likely,
more than one sorting regimen.  You could even handle three link fields
with two mixins, if you felt the urge to make your own life difficult in
that way.

Say you prefer, as indeed you might, a _singly_ linked list? We have
that as well!

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
stdlib types, and pass all the same tests, and a great many others.
They exhibit somewhat different behavior for properties not tested in
stdlib, for reasons I'll get into.

### The Shirt and Tie API

For maximum control, and incrementally less fun, we have

#### zelda.singlyLinkedList(T: type, next: anytype, m_orderFn: ?[]const u8)

The type, the name of the link field, and a name for an ordering function,
if you care to provide one.  `aLinkToThePast` figures that stuff out for you,
but you have to name your function `zeldaOrderFn`.

It should return a `zelda.Order`, this is like [`std.math.Order`][smo] but
it generates good machine code.  Zelda doesn't check this, so you can
use the other one, or something even harder to optimize, so long as it
returns `.lt`, `.eq`, and `.gt`, in a manner which leaves you happy with
the resulting stable ordering.  Oh, and declare it `inline`, every little
bit helps.

[smo]: https://ziglang.org/documentation/0.15.2/std/#std.math.Order

#### zelda.doublyLinkedList(T: type, next: anytype, prev: anytype, m_orderFn: ?[]const u8)

Same deal.  The `anytypes` let you use an enum literal, which I
encourage, as there is talk of making `@field` take a "field enum",
which should require no changes to code which prefers `.next_free` over
`"next_free"`.

You are encouraged to peruse the source, or build the docs, in order to
pick up on what all these lists have built in.

## Order, Lists, and Ordered Lists

A fairly recent modern doctrine emphasizes arrays over anything which
uses a pointer.  Linked lists are often the target of this sort of
critique, and it is indeed true that, in isolation, much of what one can
do with a linked list will benchmark faster if something similar is done
with an array instead.

While an array may be faster, this does not make linked lists slow, and
they are unmatched for flexibility.  They also give an often-useful
property of _stability_, in that no operation on a list will ever lose
a reference to an element of that list.  A direct reference, I mean.
An indirect reference... that's a different story.

I recently translated the Lemon parser [into Zig][zitron], and let me
tell you, Lemon uses linked lists for absolutely everything.  It even,
at several points, uses an `O(n²)` algorithm on these linked lists!

Lemon is _astonishingly_ fast, as is (therefore) Zitron.  It parses,
analyzes, compresses, and emits a parser of substantial complexity
in a matter of milliseconds.  While I'm at it, no one seems to have
told kernel hackers[^1] that linked lists are busted and slow, since
operating systems are postively lousy with them.

Zelda provides merge sort.  It's a pretty good sort!  It's stable,
it takes a sliver of constant space on the stack, has the optimal
worst-case sort time of `O(n log n)`, and sorts an already-sorted list
in `O(n)`.  It can't be pessimized with attacker-controlled input
either.

So don't be afraid to cons up a list, sort it, maybe sorted-insert a
few stragglers.  While amount of data exists where you would feel the
difference, it's more than you might think it is.

A notable difference between Zig-standard `SinglyLinkedList` and the
Zelda version, is that the Zelda-provided `List` type retains the tail,
as well as just the head, of the list.  There's nothing you can do with
a stdlib `SinglyLinkedList` which you can't do just with a node of a
Zelda list, and plenty you can do which the stdlib doesn't.

So why not provide a data structure which: supports `O(1)` prepend
_and_ append, concatenation in `O(1)`, which can be `O(1)` loaded onto a
freelist, and so on?  Why not indeed.  It costs you an extra pointer, I
suppose.

[zitron]: https://github.com/mnemnion/zitron/
[^1]: I'm sure this is not actually true, the Internet being what it is.
Fortunately they don't listen, and you shouldn't either!

### Finding and Filtering

Doubly-linked lists have a `Matcher` type, this is a type erased
`?*anyopaque` paired with a pointer to a match function, which takes
your node type and returns a `bool`.  By creating one of these your code
gains access to a collection of finding and find-remove operations, the
apotheosis of which is filter.

Filter is a canonical example of what makes linked lists powerful.  In
one pass, we separate what we want from the rest of what we have, with
no need to allocate scrach space or move anything around.  Pretty nice.

A later release is likely to extend this privilege to singly-linked
lists as well, but I'm running out of time to spare on buffing linked
lists.  For now.

### ZELDA_SEEK_LIMIT

If your type defines a numeric value for `ZELDA_SEEK_LIMIT`, any
iteration which does more cycles than that limit will panic the program.

It is legal, but discouraged, to use the style-guide-approved form
`zelda_seek_limit`.  It is the intention of this library that all loops
used will terminate if a seek limit is declared, after no less than the
indicated number of iterations.

Should you wish to make this build-configurable, arrange for the seek
limit to be of type `@TypeOf(null)` and it will be disabled.  Note that
this is subtly different from a `?usize` which happens to have the
_value_ `null`.

## Cool, How'd You Do It?

```sh
➜  rg -F --count-matches '@field' -- src/zelda.zig
264
```

Up from 95 in the last release.

### Alright! Let's Copypasta This Bad Boy!

Have at it:
```sh
zig fetch --save https://github.com/mnemnion/zelda/archive/refs/tags/v0.2.0.tar.gz
```

## Roadmap

I'm probably going to add some stuff.

That and test more.


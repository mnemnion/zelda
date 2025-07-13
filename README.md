# Zelda: Type Safe Intrusive Linked Lists

Zig's master branch just recently (April 2025) introduced a new interface for [SinglyLinkedList](https://ziglang.org/documentation/0.14.0/std/#std.linked_list.SinglyLinkedList) and [DoublyLinkedList](https://ziglang.org/documentation/master/std/#std.DoublyLinkedList).  Prior to the change, these were 'textbook' linked lists, with a data pointer and one or two link pointers.

As of the change, both are now [intrusive](https://www.openmymind.net/Zigs-New-LinkedList-API/), meaning that the link or links are now fields on a parent struct.  As discussed in that article, and further discussed on [The Orange Website](https://news.ycombinator.com/item?id=43679707), these are usually what you want.

Having had it in the back of my mind to do so, I took the opportunity to write a little library which, I claim, represents an improvement over the master branch implementation, under most, but perhaps not all, circumstances.

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

    // The fun part:
    pub usingnamespace zelda.aLinkBetweenWorlds(@This(), .next, .previous);

    // Also valid:
    // pub usingnamespace zelda.doublyLinkedList(@This(), "next", "previous");
    // But where's the fun in that?

    // Not-linked-list declarations go here
};
```
This function first validates that the fields in question exist, and have the requisite type to be Links.  It then returns a container namespace decorated with various node operations useful to a doubly-linked list, as well as adding a list type specialized to the parent, in this case, `Monster.DoublyLinkedList`.

Then, through the magic of `usingnamespace`, a marvelous high-level feature of Zig, greatly loved by developers with discernment, it adds the public declarations of that container to the type under construction.  Without this, one would have to tediously list them, one after the other.  ZLS can follow this fine, btw.

Of course, if you prefer to expose only a subset of those declarations, you may: simply make a private declaration to hold the return value, and add such declarations as you please.  This is also useful if you need some of the declarations to have a different name.

Which you might, because `aLinkBetweenWorlds`, I mean, `doublyLinkedList`, is composable.  If you have four fields representing two doubly-linked lists, call it twice with (disjoint!) pairs of those fields, and rename operations accordingly.  Care is taken in the implementation never to use (what become) member functions _as_ member functions, so renaming and duplication are a-ok.

Say you prefer, as indeed you might, a _singly_ linked list? We have that as well!

> It's yours, my friend, as long as you have enough rupees.

```zig
const Chunk64 = struct {
    data: [64]u8 = undefined;
    next_free: ?*@This() = null,

    pub usingnamespace zelda.aLinkToThePast(@This(), .next);

    // If you hate fun, or, I admit, care about the next poor soul
    // who might have to figure your code out:
    // pub usingnamespace zelda.singlyLinkedList(@This(), "next");

    // Yes, enum literals and strings mix and match for all four function names.
    // Be weird if they didn't, right?
};
```

Now your `Chunk64` will do single-linked node things, and has `Chunk64.SinglyLinkedList` to manage your freelist.

These types are a proper superset of the functionality given by the stdlib types, and pass all the same tests, after light porting which primarily consists of removing code.  They exhibit somewhat different behavior for properties not tested in stdlib, for reasons I'll get into.

## Cool, How'd You Do It?

```sh
➜  rg -F --count-matches '@field' -- src/zelda.zig
95
```
This number might fairly be expected to increase.

## Advantages (Our Last Line of Defense Will Be Link)

Strictly, these are "tradeoffs", but ones I happen to think will be advantageous more often than not.

In the stdlib vision of linking, the links are fully generic.  They have a type, it's up to the user to keep an eye on which kind of list it makes sense to put a given Node onto.  `zelda` makes this a compiler problem instead of a you problem.

The pointers also point (or do not) to the data itself, not to a field in the data.  There is no need to calculate the offset of the head of the structure using `@fieldParentPointer`, and therefore, no opportunity to evince unchecked illegal behavior due to a mistake in calculating that offset.  There are plans to make this sort of thing _checked_ illegal behavior, which I welcome, but I prefer compile time errors to their run time cousins.

The _possible_ disadvantage is that these are _not_ generic, and therefore it is likely, but not guaranteed, that the compiler will specialize the various functions provided for each type which is sent to Hyrule to rescue the Princess.  A highly constrained embedded systems program might prefer to guarantee once-only compilation by using a generic type, and happily pay the bookkeeping cost and error risk of tracking types through the code to ensure proper behavior.

My suspicion is that if the Node field or fields are at the same offset for several structs, LLVM will specialize several times and then merge them.  At present Zig lays out structs early enough that the later parts of the pipeline cannot inform that process of an opportunity to put fields at the same offset thereby saving code, although this is not inevitable.  This can be achieved durably with `extern` and on a fragile basis by studying how struct layout works and tweaking the code, I would check if LLVM can actually eliminate dupes before going to that kind of trouble.

Regardless, many of us are happy to take the risk of more code instead of the risk of illegal memory access at runtime.  Zelda makes that tradeoff.

#### You Mentioned Some Differences?

Ah. Right.  In stdlib, links are not made `null` when removed, and they _are_ made `null` when added in certain ways.

In `zelda`, we remove links by a) removing the link from the list and b) removing the list from the link.  In consequence, unexpected things might happen if a link which we expect to be `null` (as it would be, as a consequence of using the provided API), is not `null`.

We do this for a simple reason: fear.

### Alright! Let's Copypasta This Bad Boy!

Have at it:
```sh
zig fetch --save https://github.com/mnemnion/zelda/archive/refs/tags/v0.1.0.tar.gz
```

## Roadmap

I'm probably going to add some stuff.

That and test more.


package com.example.yiijingcompass.model

import android.graphics.PointF

data class FamilyRoomAssignment(val personID: String, val roomID: String)
data class FamilyRoomPerson(val id: String, val name: String, val guaKey: String)
data class FamilyRoomFit(val person: FamilyRoomPerson, val star: StarLuckType?, val rank: Int, val reasonKey: String) {
    val isRecommended get() = star?.isAuspicious == true
}

object FamilyRoomAllocationEngine {
    enum class RoomUse { BEDROOM, STUDY }
    fun use(type: FloorplanRoomType): RoomUse? = when(type) {
        FloorplanRoomType.MASTER_BEDROOM, FloorplanRoomType.SECOND_BEDROOM -> RoomUse.BEDROOM
        FloorplanRoomType.STUDY -> RoomUse.STUDY
        else -> null
    }
    fun isAssignable(room: FloorplanRoom) = use(room.type) != null && room.rect.left.isFinite() &&
        room.rect.top.isFinite() && room.rect.width().isFinite() && room.rect.height().isFinite() && room.rect.width() > 0 && room.rect.height() > 0
    fun people(profile: UserKuaProfileManager = UserKuaProfileManager.instance): List<FamilyRoomPerson> =
        if (!profile.isProfileEnabled) emptyList() else listOf(FamilyRoomPerson("owner", LocalizationManager.instance.t("fra_owner"), profile.ownerGuaKey)) +
            profile.familyMembers.map { FamilyRoomPerson("family:${it.id}", it.displayName, it.guaKey) }
    fun palace(room: FloorplanRoom, rooms: List<FloorplanRoom>, centroid: PointF, heading: Double, aspectRatio: Float): String? {
        if (!isAssignable(room) || !heading.isFinite() || !centroid.x.isFinite() || !centroid.y.isFinite() || !aspectRatio.isFinite() || aspectRatio <= 0) return null
        val central = rooms.filter { it.type != FloorplanRoomType.MISSING_CORNER && FloorplanEngine.roomContains(it, centroid) }.minByOrNull { it.area }
        if (central?.id == room.id) return null
        val angle = (GeometryUtils.bearing(centroid, room.center, aspectRatio) + heading % 360 + 720) % 360
        return listOf("坎", "艮", "震", "巽", "离", "坤", "兑", "乾")[((angle + 22.5) % 360 / 45).toInt()]
    }
    fun fits(room: FloorplanRoom, rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>, centroid: PointF,
        heading: Double, aspectRatio: Float): List<FamilyRoomFit> {
        if (!isAssignable(room)) return emptyList()
        val gua = palace(room, rooms, centroid, heading, aspectRatio)
        return people.map { person ->
            val star = gua?.let { target -> BaZhaiEngine.instance.analyze(person.guaKey, "离").items.firstOrNull { it.guaName == target }?.star }
            val study = room.type == FloorplanRoomType.STUDY
            val rank = when(star) {
                StarLuckType.FU_WEI -> if (study) 100 else 80
                StarLuckType.YAN_NIAN -> if (study) 80 else 100
                StarLuckType.TIAN_YI -> if (study) 70 else 95
                StarLuckType.SHENG_QI -> if (study) 90 else 75
                else -> 0
            }
            FamilyRoomFit(person, star, rank, if (star == null) "fra_center" else if (star.isAuspicious)
                (if (study) "fra_fit_study" else "fra_fit_rest") else "fra_review")
        }.sortedWith(compareByDescending<FamilyRoomFit> { it.rank }.thenBy { it.person.id })
    }
    fun cleaned(assignments: List<FamilyRoomAssignment>, rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>): List<FamilyRoomAssignment> {
        val personIDs = people.map { it.id }.toSet(); val occupied = mutableSetOf<String>()
        return assignments.filter { item ->
            val room = rooms.firstOrNull { it.id == item.roomID }
            item.personID in personIDs && room != null && isAssignable(room) &&
                occupied.add(item.personID + if (room.type == FloorplanRoomType.STUDY) ":study" else ":bedroom")
        }
    }
    fun recommend(rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>, centroid: PointF, heading: Double,
        aspectRatio: Float, hasMembershipAccess: Boolean): List<FamilyRoomAssignment> {
        if (!hasMembershipAccess) return emptyList()
        return people.flatMap { person -> listOf(false, true).mapNotNull { study ->
            rooms.filter { isAssignable(it) && (it.type == FloorplanRoomType.STUDY) == study }.mapNotNull { room ->
                fits(room, rooms, listOf(person), centroid, heading, aspectRatio).firstOrNull()?.takeIf { it.isRecommended }?.let { room.id to it.rank }
            }.sortedWith(compareByDescending<Pair<String, Int>> { it.second }.thenBy { it.first }).firstOrNull()
                ?.let { FamilyRoomAssignment(person.id, it.first) }
        } }
    }
    fun resolve(manual: List<FamilyRoomAssignment>?, rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>,
        centroid: PointF, heading: Double, aspectRatio: Float, hasMembershipAccess: Boolean): List<FamilyRoomAssignment> =
        if (!hasMembershipAccess) emptyList() else manual?.let { cleaned(it, rooms, people) }
            ?: recommend(rooms, people, centroid, heading, aspectRatio, true)
    fun labels(assignments: List<FamilyRoomAssignment>, people: List<FamilyRoomPerson>): Map<String, String> =
        assignments.groupBy { it.roomID }.mapValues { (_, items) -> people.filter { person -> items.any { it.personID == person.id } }.joinToString("、") { it.name } }
    fun afterChangingRoomUse(manual: List<FamilyRoomAssignment>?, roomID: String, from: FloorplanRoomType, to: FloorplanRoomType) =
        if (use(from) == use(to)) manual else manual?.filterNot { it.roomID == roomID }
    fun reviewRoomIDs(assignments: List<FamilyRoomAssignment>, rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>,
        centroid: PointF, heading: Double, aspectRatio: Float): Set<String> = rooms.filter { room ->
        fits(room, rooms, people, centroid, heading, aspectRatio).any { fit -> !fit.isRecommended && assignments.any { it.roomID == room.id && it.personID == fit.person.id } }
    }.map { it.id }.toSet()
    fun toggling(personID: String, room: FloorplanRoom, assignments: List<FamilyRoomAssignment>,
        rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>): List<FamilyRoomAssignment> {
        val current = cleaned(assignments, rooms, people)
        if (!isAssignable(room) || people.none { it.id == personID }) return current
        val wasAssigned = current.any { it.personID == personID && it.roomID == room.id }
        val result = current.filterNot { item -> item.personID == personID && rooms.any { it.id == item.roomID && (it.type == FloorplanRoomType.STUDY) == (room.type == FloorplanRoomType.STUDY) } }
        return if (wasAssigned) result else result + FamilyRoomAssignment(personID, room.id)
    }
}

data class FamilyRoomExportSnapshot(val labels: Map<String, String>, val report: List<FloorplanAuditItem>) {
    companion object {
        fun capture(manual: List<FamilyRoomAssignment>?, rooms: List<FloorplanRoom>, people: List<FamilyRoomPerson>,
            centroid: PointF, heading: Double, aspectRatio: Float, hasMembershipAccess: Boolean, includePeople: Boolean): FamilyRoomExportSnapshot {
            if (!hasMembershipAccess || !includePeople || people.isEmpty()) return FamilyRoomExportSnapshot(emptyMap(), emptyList())
            val assignments = FamilyRoomAllocationEngine.resolve(manual, rooms, people, centroid, heading, aspectRatio, true)
            val labels = FamilyRoomAllocationEngine.labels(assignments, people).toMutableMap()
            val lang = LocalizationManager.instance
            val report = rooms.mapNotNull { room ->
                val fits = FamilyRoomAllocationEngine.fits(room, rooms, people, centroid, heading, aspectRatio)
                    .filter { fit -> assignments.any { it.roomID == room.id && it.personID == fit.person.id } }
                if (fits.isEmpty()) return@mapNotNull null
                val review = fits.any { !it.isRecommended }
                if (review) labels[room.id]?.let { labels[room.id] = "⚠︎ $it" }
                FloorplanAuditItem("family-room-${room.id}", lang.t("fra_title") + " · " + room.name + " · " + lang.t(if (manual == null) "fra_suggested" else "fra_assigned"),
                    room.palaceName, if (review) "提示" else "吉", fits.joinToString("\n") { it.person.name + " · " + lang.t(it.reasonKey) }, lang.t("fra_note"))
            }.toMutableList()
            val unassigned = people.filter { person -> assignments.none { item -> item.personID == person.id && rooms.any { it.id == item.roomID && it.type != FloorplanRoomType.STUDY } } }
            if (unassigned.isNotEmpty()) report.add(FloorplanAuditItem("family-unassigned", lang.t("fra_title") + " · " + lang.t("fra_check"), "", "提示",
                unassigned.joinToString("、") { it.name } + " · " + lang.t("fra_no_bedroom"), lang.t("fra_no_match")))
            return FamilyRoomExportSnapshot(labels, report)
        }
    }
}

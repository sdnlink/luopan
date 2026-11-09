import SwiftUI

struct FamilyRoomAllocationSection: View {
    let rooms: [FloorplanRoom]
    let centroid: CGPoint
    let heading: Double
    let aspectRatio: CGFloat
    let houseContext: CompassHeadingState
    let manualAssignments: [FamilyRoomAssignment]?
    @Binding var showLabels: Bool
    let onUpdate: ([FamilyRoomAssignment]?) -> Void
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var profile = UserKuaProfileManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showEditor = false
    @State private var showProfiles = false
    @State private var showPaywall = false

    init(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat,
         houseContext: CompassHeadingState, manualAssignments: [FamilyRoomAssignment]?,
         showLabels: Binding<Bool>, onUpdate: @escaping ([FamilyRoomAssignment]?) -> Void) {
        self.rooms = rooms
        self.centroid = centroid
        self.heading = heading
        self.aspectRatio = aspectRatio
        self.houseContext = houseContext
        self.manualAssignments = manualAssignments
        self._showLabels = showLabels
        self.onUpdate = onUpdate
    }

    private var people: [FamilyRoomPerson] { FamilyRoomAllocationEngine.people(profile: profile) }
    private var assignments: [FamilyRoomAssignment] {
        FamilyRoomAllocationEngine.resolve(manual: manualAssignments, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio, hasAnnualAccess: iap.canUseFamilyRoomAllocation)
    }

    private var unassignedPeople: [FamilyRoomPerson] {
        let plan = assignments
        return people.filter { person in
            !plan.contains { assignment in
                assignment.personID == person.id && rooms.contains { $0.id == assignment.roomID && $0.type != .study }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(lang.t("fra_title"), systemImage: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(lang.t("fra_annual"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
            }
            if !iap.canUseFamilyRoomAllocation {
                Text(lang.t("fra_paywall"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                Button(lang.t("fra_unlock")) { showPaywall = true }
                    .buttonStyle(.borderedProminent)
            } else if !profile.isProfileEnabled {
                Button(lang.t("fra_add_family")) { showProfiles = true }
            } else {
                Toggle(lang.t("fra_show_labels"), isOn: $showLabels)
                    .font(.system(size: 12))
                HStack {
                    Button(lang.t("fra_manage")) { showEditor = true }
                        .buttonStyle(.borderedProminent)
                    Button(lang.t("fra_add_family")) { showProfiles = true }
                        .buttonStyle(.bordered)
                }.font(.system(size: 12))
                if assignments.isEmpty { Text(lang.t("fra_no_match")).font(.system(size: 12)).foregroundColor(.orange) }
                else if !unassignedPeople.isEmpty {
                    Text(unassignedPeople.map(\.name).joined(separator: "、") + " · " + lang.t("fra_no_bedroom"))
                        .font(.system(size: 12)).foregroundColor(.orange)
                }
                Text(lang.t(manualAssignments == nil ? "fra_suggested" : "fra_assigned"))
                    .font(.system(size: 11)).foregroundColor(.cyan)
            }
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPaywall) { VIPPaywallSheet(annualOnly: true) }
        .sheet(isPresented: $showProfiles) {
            OwnerLifeGuaView(context: houseContext)
        }
        .sheet(isPresented: $showEditor) {
            NavigationView {
                Group {
                    if iap.canUseFamilyRoomAllocation && profile.isProfileEnabled { editor }
                    else { Text(lang.t("fra_paywall")).padding() }
                }
                .navigationTitle(lang.t("fra_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.t("done")) { showEditor = false }
                } }
                .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
                .foregroundColor(.white)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(lang.t("fra_note")).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                HStack {
                    Button(lang.t("fra_auto")) { onUpdate(nil) }
                    Spacer()
                    Button(lang.t("fra_clear")) { onUpdate([]) }
                }.buttonStyle(.bordered)
                if !rooms.contains(where: FamilyRoomAllocationEngine.isAssignable) {
                    Text(lang.t("fra_no_rooms")).foregroundColor(.orange)
                }
                ForEach(rooms.filter(FamilyRoomAllocationEngine.isAssignable)) { room in
                    roomCard(room)
                }
                ForEach(unassignedPeople) { person in
                    Text(person.name + " · " + lang.t("fra_no_bedroom"))
                        .font(.system(size: 12)).foregroundColor(.orange)
                }
            }.padding(16)
        }
    }

    private func roomCard(_ room: FloorplanRoom) -> some View {
        let fits = FamilyRoomAllocationEngine.fits(room: room, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio)
        return VStack(alignment: .leading, spacing: 10) {
            Label(room.name + " · " + room.palaceName, systemImage: room.type.iconName)
                .font(.system(size: 14, weight: .bold))
            ForEach(fits, id: \.person.id) { fit in
                let selected = assignments.contains { $0.roomID == room.id && $0.personID == fit.person.id }
                Button {
                    guard iap.canUseFamilyRoomAllocation else { return }
                    onUpdate(FamilyRoomAllocationEngine.toggling(personID: fit.person.id, room: room,
                        assignments: assignments, rooms: rooms, people: people))
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected ? .cyan : .gray)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(fit.person.name).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text(lang.t(fit.isRecommended ? "fra_good" : "fra_check"))
                                    .font(.system(size: 11))
                                    .foregroundColor(fit.isRecommended ? .green : .orange)
                            }
                            Text(lang.t(fit.reasonKey)).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                            if let star = fit.star {
                                Text(star.localizedName).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }.padding(8)
                        .background(selected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.03))
                        .cornerRadius(8)
                }.buttonStyle(.plain)
            }
        }.padding(12).background(Color.white.opacity(0.05)).cornerRadius(12)
    }
}

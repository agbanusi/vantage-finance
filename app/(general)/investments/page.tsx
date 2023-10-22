"use client"

import React from "react"
import Link from "next/link"
import {
  integrationCategories,
  turboIntegrations,
} from "@/data/turbo-integrations"

import { siteConfig } from "@/config/site"
import {
  NavigationMenu,
  NavigationMenuContent,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  NavigationMenuTrigger,
  navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu"
import { Separator } from "@/components/ui/separator"
import { LightDarkImage } from "@/components/shared/light-dark-image"

export default function MainNavMenu() {
  return (
    <NavigationMenu>
      <NavigationMenuList>
        <ul className="grid w-[400px] gap-3 p-4 md:w-[500px] md:grid-cols-2 lg:w-[768px] lg:grid-cols-3">
          {integrationCategories.map((category) => (
            <>
              <h4
                key={category}
                className="text-lg font-medium leading-none md:col-span-2 lg:col-span-3"
              >
                {category.charAt(0).toUpperCase() + category.slice(1)}
              </h4>
              <Separator className="md:col-span-2 lg:col-span-3" />
              {Object.values(turboIntegrations)
                .filter((integration) => integration.category === category)
                .map(({ name, href, description, imgDark, imgLight }) => (
                  <NavMenuListItem
                    key={name}
                    name={name}
                    href={href}
                    description={description}
                    lightImage={imgDark}
                    darkImage={imgLight}
                  />
                ))}
            </>
          ))}
        </ul>
      </NavigationMenuList>
    </NavigationMenu>
  )
}

interface NavMenuListItemProps {
  name: string
  description: string
  href: string
  lightImage: string
  darkImage: string
}

const NavMenuListItem = ({
  name,
  description,
  href,
  lightImage,
  darkImage,
}: NavMenuListItemProps) => {
  return (
    <li className="w-full min-w-full" key={name}>
      <NavigationMenuLink asChild>
        <a
          href={href}
          className="flex select-none flex-col gap-y-2 rounded-md p-3 leading-none no-underline outline-none transition-colors hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground"
        >
          <div className="flex items-center gap-x-2">
            <LightDarkImage
              LightImage={lightImage}
              DarkImage={darkImage}
              alt="icon"
              height={24}
              width={24}
              className="h-6 w-6"
            />
            <span className="text-base font-medium leading-none">{name}</span>
          </div>
          <p className="line-clamp-2 text-sm leading-snug text-muted-foreground">
            {description}
          </p>
        </a>
      </NavigationMenuLink>
    </li>
  )
}
